use strict;
use Test;
BEGIN { plan tests => 2 }

use Cwd qw(abs_path); 
use VFS::GnomeVFS;
#use Data::Dumper;
ok(1);

ok(test1());




# test subroutines
sub test1 {

  my $file = "file://".abs_path(".")."/testout.txt";
#  warn Dumper( vfsstat($file) )."\n";
  return vfsstat($file) == 15 ? 1 : 0;

}

