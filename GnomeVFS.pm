package VFS::GnomeVFS;
use strict;
require 5.006;
use Carp;
require DynaLoader;
require Exporter;
use vars qw(@ISA $VERSION @EXPORT_OK $RUN_ONCE);
$VERSION = '0.02';
@ISA = qw(DynaLoader Exporter);

use Data::Dumper;

sub dl_load_flags { 0x01 }
VFS::GnomeVFS->bootstrap($VERSION);


# export the open command, and initialise gnome-vfs
my @export_ok = ("vfsopen", "vfsexists", "vfsstat", "vfsmove", "vfsunlink", "vfsopendir" );
sub import {

  my ( $caller ) = caller;

  no strict 'refs';
  foreach my $sub ( @export_ok ){
    *{"${caller}::${sub}"} = \&{$sub};
  }

  # initialise the vfs engine
  do_vfs_init();

}

# open a file handle with vfs
sub vfsopen {

  my ( $caller ) = caller;
  my $handle = shift;
  $handle =~ s/.*:://;
  no strict 'refs';
  return tie *{"${caller}::${handle}"}, __PACKAGE__, @_;

}

# open a directory handle with vfs
sub vfsopendir {

  my ( $caller ) = caller;
  my $handle = shift;
  $handle =~ s/.*:://;
  no strict 'refs';
  return tie *{"${caller}::${handle}"}, __PACKAGE__, @_;

}

# check that the uri exists
sub vfsexists {

  my $uri = shift;
  return do_vfs_exists($uri);

}

# get posix style stats on uri
sub vfsstat {

  my $uri = shift;
  my $stats = do_vfs_stat($uri);
  if (ref($stats)){
    return @{$stats};
  } else {
    return $stats;
  }

}

# move one uri to another
sub vfsmove {

  my ($furi, $turi) = @_;
  die "from uri($furi) does not exist\n"
     unless vfsexists($furi);
  die "to uri does not exist\n"
     unless $turi;
  return do_vfs_move($furi, $turi);

}

# unlink/delete a given uri
sub vfsunlink {

  my $uri = shift;
  die "uri($uri) to delete does not exist\n"
     unless vfsexists($uri);
  return do_vfs_unlink($uri);

}


# instantiate the tied object
sub TIEHANDLE {

  my $caller = (caller(1))[3];
  $caller =~ s/.*:://;
  my $class = shift;
  my $file = shift;

  # determine if this is a file or directory call
  if ($caller eq 'vfsopen'){
    my ($meth, $uri) = $file =~ /^([\<\>]+)(.*?)$/;

    die "No file open method specified - $file\n"
      unless $meth;
    die "no open method/file name specified - $file\n"
      unless $uri;
    die "open method unsupported - $file\n"
      unless $meth eq '<' or $meth eq '>' or $meth eq '>>';

    my $self = { 'uri' => $file, 
                 'type' => 'file',
                 'rows' => [],
                 'buffer' => "",
                 'eof' => undef,
                 'nline' => $/,
                 'handle' => 
		   do_vfs_open($uri, $meth =~ />/ ? 1 : 0, $meth eq '>>' ? 1 : 0)
	       };
    bless($self, $class);
    return $self;
  } elsif ($caller eq 'vfsopendir'){

    my $self = { 'uri' => $file, 
                 'type' => 'dir',
                 'rows' => [],
                 'buffer' => "",
                 'eof' => undef,
                 'handle' => do_vfs_dir_open($file)
	       };
    bless($self, $class);
    return $self;
  }

  # the TIE fails
  return undef;

}


# read next buffer of a vfs file handle
sub READLINE {

  my $self = shift;

  if ( $self->{'type'} eq 'file' ){
    if ($self->{'nline'} ne $/){
        $self->{'buffer'} = join("",@{$self->{'rows'}});
        $self->{'rows'} = [];
        $self->{'nline'} = $/;
    }

    # Find the next available record
    my $buf = "";
    # return the rest of the file
    if ( wantarray() ){
        $self->{'buffer'} .= $buf
	    while ($buf = do_vfs_read($self->{'handle'}));
        @{$self->{'rows'}} = split(/$self->{nline}/, $self->{'buffer'}, -1);
        for (my $i = 0; $i < @{$self->{'rows'}} - 1; $i++){
          $self->{'rows'}->[$i] .= $self->{'nline'};
  	}
        $self->{'buffer'} = undef;
	$self->{'eof'} = 1;
	my $last = $self->{'rows'}->[-1];
	pop@{$self->{'rows'}} unless defined($last);
	return @{$self->{'rows'}};
     
    # get the next record
    } else {
      while ( ! $self->{'eof'} && scalar @{$self->{'rows'}} < 1  ){
        $buf =  do_vfs_read($self->{'handle'});
        # drop out if we are at the end of the file
        if ( ! defined($buf) ){
          $self->{'eof'} = 1;
          @{$self->{'rows'}}  = ( $self->{'buffer'} );
	  last;
	}

	# ok - we got some
        $self->{'buffer'} .= $buf;
        if ( $self->{'buffer'} =~ /$self->{nline}/s ){
          @{$self->{'rows'}} = split(/$self->{nline}/, $self->{'buffer'}, -1);
	  $self->{'buffer'} = pop(@{$self->{'rows'}});
          foreach (@{$self->{'rows'}}){
            $_ .= $self->{'nline'};
  	  }
          last;
        }
      }
      return @{$self->{'rows'}} ? shift(@{$self->{'rows'}}) : undef;
    }

  } elsif ( $self->{'type'} eq 'dir' ){
      # return a list of directories if in array context
      if (wantarray()){
       my @dir = ();
       while (my $dir = do_vfs_dir_read_next($self->{'handle'}) ){
         push(@dir, $dir->[-1]);
       }
       $self->{'eof'} = 1;
       return @dir;
      } else {
        # in scalar - return the next directory entry in stat format
        my $dirent = do_vfs_dir_read_next($self->{'handle'});
	$self->{'eof'} = 1 unless defined($dirent);
	return $dirent;
      }
  }

}


sub EOF {
 
  my $self = shift;
  # you dont do this with a directory
  return undef if $self->{'type'} eq 'dir';
  return $self->{'eof'};

}


sub BINMODE {
 die "not finished!";

}


sub UNTIE {
 die "not finished!";

}


sub DESTROY {
 #die "not finished!";

}


# print to a vfs file handle
sub PRINT {

  my $self = shift;
  # you dont do this with a directory
  return undef if $self->{'type'} eq 'dir';
  my $buffer = join("",@_);
  return do_vfs_write($self->{'handle'}, $buffer);

}


# close a vfs file handle
sub CLOSE {

  my $self = shift;
  if ($self->{'type'} eq 'dir'){
    die "Directory Close failed \n" unless do_vfs_dir_close($self->{'handle'});
  } elsif ($self->{'type'} eq 'file'){
    die "Close failed \n" unless do_vfs_close($self->{'handle'});
  }

}


#==============================================================================



=head1 NAME

VFS::GnomeVFS - Gnome Virtual Filesystem for Perl

=head1 SYNOPSIS

  use VFS::GnomeVFS;

  vfsopen(*IN, "<http://www.piersharding.com") or die $!;
  # dont forget the * when using strict
  print while (<IN>);
  close IN;
 

=head1 DESCRIPTION

VFS::GnomeVFS is a TIEHANDLE module that uses the gnome-vfs library from the Gnome
project (http://www.gnome.org).
The gnome-vfs library (Virtual File System) allows uniform access to various
uri types such as http://, https://, file://, ftp:// etc.

=head1 METHODS

=head2 vfsopen()

vfsopen is pushed into the users calling namespace via the import statement, so
there is no need to fully qualify it.

vfsopen(*FH, ">file:///tmp/some.file") or die $!;

Because use strict forbids the use of barewords, then you must remember to
use the * (typeglob notation) on your filehandle - but only for the vfsopen
there after it is not required.

VFS::GnomeVFS supports:

=over 4

=item *  '>' output to a file

=item *  '<' input from a file

=item *  '>>' append to a file ( this is broken in RH8.0 as gnome_vfs_seek is broken )

=back

=head2 other functions

once opened - a file handle behaves much like an ordinary one, in that you can
"print" to it, and read from it with the "<>" (diamond) operator.

=head2 vfsstat()

vfsstat takes a single argument of a uri and returns a 13 element array
of information  as the core perl stat() function does.

=over 4

=item      0  dev      device number of filesystem (currently undef)

=item      1  inode    inode number (currently undef)

=item      2  mode     file mode  (type and permissions in character form)

=item      3  nlink    number of (hard) links to the file

=item      4  uid      numeric user ID of file's owner

=item      5  gid      numeric group ID of file's owner

=item      6  rdev     the device identifier (special files only)

=item      7  size     total size of file, in bytes

=item      8  atime    last access time in seconds since the epoch

=item      9  mtime    last modify time in seconds since the epoch

=item     10 ctime    inode change time (NOT creation time!) in seconds since the epoch

=item     11 blksize  preferred block size for file system I/O

=item     12 blocks   actual number of blocks allocated

=item     13 type     a new entry specifying the type This can be f - file, d - directory, p - pipe, s - socket, c - character device, b - block device, l - link

=item     14 name     a new entry specifying the file name ( minus the path )

=back

=head2 vfsexists()

vfsexists takes a single argument of a uri and returns true if it exists.

=head2 vfsmove()

vfsmove takes two arguments - the from and to uri's, and returns true if the
file was successfully transported.


=head2 vfsunlink()

vfsunlink takes a single argument of a uri and returns true if the file is
successfully unlinked/deleted.

=head2 vfsopendir()

vfsopendir opens a handle on a directory in the same style as a TIED files
handle.  This is used in preference to trying to imitate the opendir, readdir, 
closedir syntax of Perl, that can not be imitated thru the tie() operation.

vfsopendir(*DIR, "file:///tmp") or die $!;

Because use strict forbids the use of barewords, then you must remember to
use the * (typeglob notation) on your filehandle - but only for the vfsopendir
there after it is not required.

subsequently the handle can be addressed in two ways:

=over 4

=item * in array context

=item * in scalar context


Array context emulates individual readdir commands of standard Perl, in that it
returns a list of names read from the given directory.

  push(@a, (<DIR>));

Scalar context returns the results of individual stat commands as an array ref.
This is what gnome-vfs does natively.  The first element of the stat array has
been highjacked to  supply the files name.

 while($dirent = <DIR>)
   push(@a, $dirent->[0]);


=head1 VERSION

very new

=head1 AUTHOR

Piers Harding - piers@cpan.org

=head1 SEE ALSO

  http://developer.gnome.org/doc/API/gnome-vfs/ and perldoc Tie::Handle

=head1 COPYRIGHT

Copyright (c) 2002, Piers Harding. All Rights Reserved.
This module is free software. It may be used, redistributed
and/or modified under the same terms as Perl itself.


=cut

1;

