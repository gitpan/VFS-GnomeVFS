use strict;
use Test;
BEGIN { plan tests => 4 }

use Cwd qw(abs_path); 
use VFS::GnomeVFS;
ok(1);

ok(test1());
ok(test2());
ok(test3());




# test subroutines
sub test1 {

  # test that 0 last value works
  my $data =  "This is a test of outputing a file\n0";
  my $file = "file://".abs_path(".")."/testout.txt";
  #warn "The file is: $file\n";
  vfsopen(*OUT, ">$file") or return 0;
  #warn "outputing test 1\n";
  print OUT $data;
  close OUT;
  vfsopen(*IN, "<$file") or return 0;
  my $rows = join("",(<IN>));
  #warn "read: $rows";
  close IN;
  return $rows eq $data ? 1 : 0;

}


sub test2 {

  # test that \n last value works
  my $data =  "This is a test of outputing a file\n";
  my $file = "file://".abs_path(".")."/testout.txt";
  #warn "The file is: $file\n";
  vfsopen(*OUT, ">$file") or return 0;
  #warn "outputing test 2\n";
  print OUT $data;
  close OUT;
  vfsopen(*IN, "<$file") or return 0;
  my $rows = join("",(<IN>));
  #warn "read: $rows";
  close IN;
  return $rows eq $data ? 1 : 0;

}


sub test3 {

  # test that \n last value works
  my $data =  "This is a test of\n outputing a file\n\n\n";
  my $file = "file://".abs_path(".")."/testout.txt";
  #warn "The file is: $file\n";
  vfsopen(*OUT, ">$file") or return 0;
  #warn "outputing test 3\n";
  print OUT $data;
  close OUT;
  vfsopen(*IN, "<$file") or return 0;
  my $rows = join("",(<IN>));
  #warn "read: $rows";
  close IN;
  return $rows eq $data ? 1 : 0;

}


