#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include <libgnomevfs/gnome-vfs.h>
//#include <time.h>

#define BUF_SIZE 8192
//#define BUF_SIZE 2048


SV* do_vfs_open(SV* sv_uri, SV* sv_mode, SV* sv_append){

  GnomeVFSHandle   *handle;
  GnomeVFSResult    result;
  guint perms;

  //fprintf(stderr, "The open mode is: %d \n", SvIV(sv_mode));
  //fprintf(stderr, "The open append is: %d \n", SvIV(sv_append));
  // we are reading this file
  if (SvIV(sv_mode) == 0){
    result = gnome_vfs_open (&handle, (gchar *) SvPV(sv_uri,SvCUR(sv_uri)), GNOME_VFS_OPEN_READ);
  } else {
  // we are writing to this file - do we append
    if (SvIV(sv_append) == 1){
      result = gnome_vfs_open (&handle, (gchar *) SvPV(sv_uri,SvCUR(sv_uri)), GNOME_VFS_OPEN_WRITE);
      if (result == GNOME_VFS_ERROR_NOT_FOUND){
        perms =  GNOME_VFS_PERM_USER_READ | GNOME_VFS_PERM_USER_WRITE |
                 GNOME_VFS_PERM_GROUP_READ | GNOME_VFS_PERM_OTHER_READ;
        result = gnome_vfs_create (&handle, (gchar *) SvPV(sv_uri,SvCUR(sv_uri)),
                                     GNOME_VFS_OPEN_WRITE, TRUE, perms);
        //fprintf(stderr, "The result of create is: %d \n", result);
      } else {
        result = gnome_vfs_seek (handle, GNOME_VFS_SEEK_END, 0);
        //fprintf(stderr, "The result of open-seek is: %d \n", result);
      }
    } else {
    // this is a new/truncate
      if (gnome_vfs_uri_exists (gnome_vfs_uri_new((gchar *) SvPV(sv_uri,SvCUR(sv_uri))))){
        result = gnome_vfs_open (&handle, (gchar *) SvPV(sv_uri,SvCUR(sv_uri)), GNOME_VFS_OPEN_WRITE);
        if (result != GNOME_VFS_OK) {
          return newSVsv(&PL_sv_undef);
        }
        result = gnome_vfs_truncate_handle (handle, 0);

      } else {
        perms =  GNOME_VFS_PERM_USER_READ | GNOME_VFS_PERM_USER_WRITE |
                 GNOME_VFS_PERM_GROUP_READ | GNOME_VFS_PERM_OTHER_READ;
        result = gnome_vfs_create (&handle, (gchar *) SvPV(sv_uri,SvCUR(sv_uri)),
                                     GNOME_VFS_OPEN_WRITE, TRUE, perms);
        //fprintf(stderr, "The result of create is: %d \n", result);
      }
    }
  }
  //fprintf(stderr, "The result of open is: %d \n", result);
  if (result != GNOME_VFS_OK) {
    return newSVsv(&PL_sv_undef);
  }
  return sv_setref_pv(newSViv(0), Nullch, (void *)handle);

}


SV* do_vfs_close(SV* sv_handle){

  GnomeVFSHandle   *handle;
  GnomeVFSResult    result;

  handle = ((GnomeVFSHandle*)SvIV(SvRV(sv_handle)));
  result = gnome_vfs_close (handle);
  //fprintf(stderr, "close result: %d \n", result);
  if (result != GNOME_VFS_OK) {
    return newSVsv(&PL_sv_undef);
  } else {
    return newSVsv(&PL_sv_yes);
  }

}


SV* do_vfs_read(SV* sv_handle){

  GnomeVFSHandle   *handle;
  GnomeVFSResult    result;
  gchar             buffer[BUF_SIZE];
  GnomeVFSFileSize  bytes_read;
  SV*               my_buffer;

  handle = ((GnomeVFSHandle*)SvIV(SvRV(sv_handle)));
  my_buffer = newSVpvf("");

  result = gnome_vfs_read (handle, buffer, BUF_SIZE, &bytes_read);
  //fprintf(stderr, "bytes read: %d - result: %d \n", bytes_read, result);
  if (bytes_read == 0){
    return newSVsv(&PL_sv_undef);
   } else {
    return newSVpvn((char *) buffer, (int) bytes_read);
  }

}


SV* do_vfs_read_all(SV* sv_uri){

  GnomeVFSHandle   *handle;
  GnomeVFSResult    result;
  gchar             buffer[BUF_SIZE];
  GnomeVFSFileSize  bytes_read;
  SV*               my_file;

  result = gnome_vfs_open (&handle, (gchar *) SvPV(sv_uri,SvCUR(sv_uri)), GNOME_VFS_OPEN_READ);
  my_file = newSVpvf("");

  while (result == GNOME_VFS_OK) {
    result = gnome_vfs_read (handle, buffer, BUF_SIZE, &bytes_read);
    //fprintf(stderr, "bytes read: %d\n", bytes_read);
    sv_catpvn(my_file,(char *) buffer, (int) bytes_read);
    if (bytes_read == 0)
      break;
  }

  return my_file;

}


SV* do_vfs_write(SV* sv_handle, SV* sv_buffer){

  GnomeVFSHandle   *handle;
  GnomeVFSResult    result;
  GnomeVFSFileSize  bytes, bytes_written, offset;

  handle = ((GnomeVFSHandle*)SvIV(SvRV(sv_handle)));
  bytes = SvCUR(sv_buffer);
  //fprintf(stderr, "bytes to write: %d\n", bytes);
  //result = gnome_vfs_tell(handle, &offset);
  //fprintf(stderr, "current offset on write handle: %d - %d\n", offset, result);
  while (bytes > 0) {
    result = gnome_vfs_write (handle, SvPV(sv_buffer, SvCUR(sv_buffer)), bytes, &bytes_written);
    //fprintf(stderr, "bytes written: %d - result: %d \n", bytes_written, result);
    if (result != GNOME_VFS_OK) {
      return newSVsv(&PL_sv_undef);
    }
    bytes -= bytes_written;
  }
  //return GNOME_VFS_OK;
  return newSVsv(&PL_sv_yes);

}


void do_vfs_init(void){

    gnome_vfs_init();

}


SV* do_vfs_exists(SV* sv_uri){

  gboolean check;

  check = gnome_vfs_uri_exists (gnome_vfs_uri_new((gchar *) SvPV(sv_uri,SvCUR(sv_uri))));
  if (check == TRUE) {
    return newSVsv(&PL_sv_yes);
  } else {
    return newSVsv(&PL_sv_undef);
  }

}


SV* fileinfo_to_array(GnomeVFSFileInfo* file_info){

  gboolean check;
  SV* sv_perms;
  SV* sv_oct_perms;
  AV* my_array;
  char ftype;
  int usr = 0;
  int grp = 0;
  int oth = 0;
  int stk = 0;

  my_array = newAV();
  av_push( my_array, newSVsv(&PL_sv_undef) );
  av_push( my_array, newSVsv(&PL_sv_undef) );
  sv_perms = newSVpvf("");
  switch (file_info->type) {
    case GNOME_VFS_FILE_TYPE_REGULAR:
      //sv_catpvn(sv_perms, "-", 1);
      ftype = 'f';
      break;

    case GNOME_VFS_FILE_TYPE_DIRECTORY:
      sv_catpvn(sv_perms, "d", 1);
      ftype = 'd';
      break;

    case GNOME_VFS_FILE_TYPE_SYMBOLIC_LINK:
      sv_catpvn(sv_perms, "l", 1);
      ftype = 'l';
      break;

    case GNOME_VFS_FILE_TYPE_SOCKET:
      ftype = 's';
      break;

    case GNOME_VFS_FILE_TYPE_CHARACTER_DEVICE:
      ftype = 'c';
      break;

    case GNOME_VFS_FILE_TYPE_BLOCK_DEVICE:
      ftype = 'b';
      break;

    case GNOME_VFS_FILE_TYPE_FIFO:
      ftype = 'p';
      break;

    default:
      ftype = 'f';
      break;
  }
  //fprintf(stderr, "the file type is: %d \n", file_info->type);
  if (file_info->permissions & GNOME_VFS_PERM_STICKY ){
    sv_catpvn(sv_perms, "t", 1);
    stk += 1;
  }
  if (file_info->permissions & GNOME_VFS_PERM_SUID ){
    sv_catpvn(sv_perms, "s", 1);
    stk += 4;
  }
  if (file_info->permissions & GNOME_VFS_PERM_USER_READ ){
    sv_catpvn(sv_perms, "r", 1);
    usr += 4;
  } else {
    sv_catpvn(sv_perms, "-", 1);
  }
  if (file_info->permissions & GNOME_VFS_PERM_USER_WRITE ){
    sv_catpvn(sv_perms, "w", 1);
    usr += 2;
  } else {
    sv_catpvn(sv_perms, "-", 1);
  }
  if (file_info->permissions & GNOME_VFS_PERM_USER_EXEC ){
    sv_catpvn(sv_perms, "x", 1);
    usr += 1;
  } else {
    sv_catpvn(sv_perms, "-", 1);
  }
  if (file_info->permissions & GNOME_VFS_PERM_SGID ){
    sv_catpvn(sv_perms, "s", 1);
    stk += 2;
  }
  if (file_info->permissions & GNOME_VFS_PERM_GROUP_READ ){
    sv_catpvn(sv_perms, "r", 1);
    grp += 4;
  } else {
    sv_catpvn(sv_perms, "-", 1);
  }
  if (file_info->permissions & GNOME_VFS_PERM_GROUP_WRITE ){
    sv_catpvn(sv_perms, "w", 1);
    grp += 2;
  } else {
    sv_catpvn(sv_perms, "-", 1);
  }
  if (file_info->permissions & GNOME_VFS_PERM_GROUP_EXEC ){
    sv_catpvn(sv_perms, "x", 1);
    grp += 1;
  } else {
    sv_catpvn(sv_perms, "-", 1);
  }
  if (file_info->permissions & GNOME_VFS_PERM_OTHER_READ ){
    sv_catpvn(sv_perms, "r", 1);
    oth += 4;
  } else {
    sv_catpvn(sv_perms, "-", 1);
  }
  if (file_info->permissions & GNOME_VFS_PERM_OTHER_WRITE ){
    sv_catpvn(sv_perms, "w", 1);
    oth += 2;
  } else {
    sv_catpvn(sv_perms, "-", 1);
  }
  if (file_info->permissions & GNOME_VFS_PERM_OTHER_EXEC ){
    sv_catpvn(sv_perms, "x", 1);
    oth += 1;
  } else {
    sv_catpvn(sv_perms, "-", 1);
  }
  sv_oct_perms = newSVpvf("%d%d%d%d", stk, usr, grp, oth);
  //av_push( my_array, sv_perms );
  av_push( my_array, sv_oct_perms );
  av_push( my_array, newSViv( (int) file_info->link_count ) );
  av_push( my_array, newSViv( (int) file_info->uid ) );
  av_push( my_array, newSViv( (int) file_info->gid ) );
  av_push( my_array, newSVsv(&PL_sv_undef) );
  av_push( my_array, newSViv( (int) file_info->size ) );
  av_push( my_array, newSViv( (int) file_info->atime ) );
  av_push( my_array, newSViv( (int) file_info->mtime ) );
  av_push( my_array, newSViv( (int) file_info->ctime ) );
  av_push( my_array, newSViv( (int) file_info->io_block_size ) );
  av_push( my_array, newSViv( (int) file_info->block_count ) );
  av_push( my_array, newSVpvf("%c", ftype) );
  av_push( my_array, newSVpvf("%s", file_info->name) );
  gnome_vfs_file_info_unref(file_info);
  return newRV_noinc( (SV*) my_array );

}


SV* do_vfs_stat(SV* sv_uri){

  GnomeVFSFileInfo *file_info;
  GnomeVFSResult    result;

  file_info = gnome_vfs_file_info_new ();
  result = gnome_vfs_get_file_info ((gchar *) SvPV(sv_uri,SvCUR(sv_uri)), file_info,
                                    GNOME_VFS_FILE_INFO_FOLLOW_LINKS);
  if (result != GNOME_VFS_OK) {
    gnome_vfs_file_info_unref(file_info);
    return newSVsv(&PL_sv_undef);
  } else {
    return fileinfo_to_array( file_info );
  }

}


SV* do_vfs_move(SV* sv_furi, SV* sv_turi){

  GnomeVFSResult    result;

  result = gnome_vfs_move ((gchar *) SvPV(sv_furi,SvCUR(sv_furi)),
                           (gchar *) SvPV(sv_turi,SvCUR(sv_turi)), TRUE);
  if (result != GNOME_VFS_OK) {
    return newSVsv(&PL_sv_undef);
  } else {
    return newSVsv(&PL_sv_yes);
  }

}


SV* do_vfs_unlink(SV* sv_uri){

  GnomeVFSResult    result;

  result = gnome_vfs_unlink ((gchar *) SvPV(sv_uri,SvCUR(sv_uri)));
  if (result != GNOME_VFS_OK) {
    return newSVsv(&PL_sv_undef);
  } else {
    return newSVsv(&PL_sv_yes);
  }

}


SV* do_vfs_dir_open(SV* sv_uri){

  GnomeVFSDirectoryHandle *handle;
  GnomeVFSResult    result;

// GnomeVFSResult  gnome_vfs_directory_open (GnomeVFSDirectoryHandle **handle, const gchar *text_uri, GnomeVFSFileInfoOptions options, const GnomeVFSDirectoryFilter *filter);

  result = gnome_vfs_directory_open (&handle, (gchar *) SvPV(sv_uri,SvCUR(sv_uri)),
                  GNOME_VFS_FILE_INFO_GET_MIME_TYPE+GNOME_VFS_FILE_INFO_FOLLOW_LINKS, NULL);
  if (result != GNOME_VFS_OK) {
    return newSVsv(&PL_sv_undef);
  } else {
    return sv_setref_pv(newSViv(0), Nullch, (void *)handle);
  }

}


SV* do_vfs_dir_close(SV* sv_handle){

  GnomeVFSDirectoryHandle *handle;
  GnomeVFSResult    result;

  handle = ((GnomeVFSDirectoryHandle*)SvIV(SvRV(sv_handle)));
  result = gnome_vfs_directory_close (handle);
  if (result != GNOME_VFS_OK) {
    return newSVsv(&PL_sv_undef);
  } else {
    return newSVsv(&PL_sv_yes);
  }

}


SV* do_vfs_dir_read_next(SV* sv_handle){

  GnomeVFSDirectoryHandle *handle;
  GnomeVFSFileInfo *file_info;
  GnomeVFSResult    result;

  handle = ((GnomeVFSDirectoryHandle*)SvIV(SvRV(sv_handle)));

  file_info = gnome_vfs_file_info_new ();
  result = gnome_vfs_directory_read_next (handle, file_info);
  if (result != GNOME_VFS_OK) {
    gnome_vfs_file_info_unref(file_info);
    return newSVsv(&PL_sv_undef);
  } else {
    return fileinfo_to_array( file_info );
  }

}


MODULE = VFS::GnomeVFS	PACKAGE = VFS::GnomeVFS	

PROTOTYPES: DISABLE


SV *
do_vfs_open (sv_uri, sv_mode, sv_append)
	SV *	sv_uri
	SV *	sv_mode
	SV *	sv_append

SV *
do_vfs_close (sv_handle)
	SV *	sv_handle

SV *
do_vfs_read (sv_handle)
	SV *	sv_handle

SV *
do_vfs_read_all (sv_uri)
	SV *	sv_uri

SV *
do_vfs_write (sv_handle, sv_buffer)
	SV *	sv_handle
	SV *	sv_buffer

void
do_vfs_init ( )

SV *
do_vfs_exists (sv_uri)
	SV *	sv_uri

SV*
do_vfs_stat (sv_uri)
	SV *	sv_uri

SV*
do_vfs_move (sv_furi, sv_turi)
	SV *	sv_furi
	SV *	sv_turi

SV*
do_vfs_unlink (sv_uri)
	SV *	sv_uri

SV*
do_vfs_dir_open (sv_uri)
	SV *	sv_uri

SV *
do_vfs_dir_close (sv_handle)
	SV *	sv_handle

SV *
do_vfs_dir_read_next (sv_handle)
	SV *	sv_handle

