use strict;
use Test;
BEGIN { plan tests => 2 }

use Cwd qw(abs_path); 
use VFS::GnomeVFS;
ok(1);

ok(test1());




# test subroutines
sub test1 {

  my $file = "file://".abs_path(".")."/testout.txt";
  my $target = "file://".abs_path(".")."/testout1.txt";
  vfsmove($file, $target);
  return vfsexists($target) ? 1 : 0;

}

