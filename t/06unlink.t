use strict;
use Test;
BEGIN { plan tests => 2 }

use Cwd qw(abs_path); 
use VFS::GnomeVFS;
ok(1);

ok(test1());




# test subroutines
sub test1 {

  my $file = "file://".abs_path(".")."/testout1.txt";
  return vfsunlink($file) ? 1 : 0;

}

