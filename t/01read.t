use strict;
use Test;
BEGIN { plan tests => 5 }

use VFS::GnomeVFS;
ok(1);

ok(test1());
ok(test2());
ok(test3());
ok(test4());

my $cnt = 0;
my @a = ();
my @b = ();
# test subroutines
sub test1 {

  #vfsopen(*IN, "<http://www.piersharding.com/index.html") or return 0;
  vfsopen(*IN, "<http://www.piersharding.com") or return 0;
  my @rows = (<IN>);
  close IN;
  $cnt = @rows;
  @a = @rows;
  #warn "row count: $cnt\n";
  return @rows > 0 ? 1 : 0;

}

# test subroutines
sub test2 {

  #vfsopen(*IN, "<http://www.piersharding.com/index.html") or return 0;
  vfsopen(*IN, "<http://www.piersharding.com") or return 0;
  my @rows;
  push(@rows, $_) while(<IN>);
  close IN;
  @b = @rows;
  #warn "row count is now: ".scalar @rows."\n";
  foreach (0..$#a){
    #warn "$_: a($a[$_]) diff b($b[$_]) \n" if $a[$_] ne $b[$_];
    return 0 if $a[$_] ne $b[$_];
  }
  foreach (0..$#b){
    #warn "$_: b($b[$_]) diff a($a[$_]) \n" if $a[$_] ne $b[$_];
    return 0 if $a[$_] ne $b[$_];
  }
  return @rows > 0 ? 1 : 0;

}


my @dira = ();
sub test3 {

  vfsopendir(*DIR, "file:///tmp") or return 0;
  my @rows;
  push(@rows, (<DIR>));
  close DIR;
  @dira = @rows;
  #use Data::Dumper;
  #warn "a dirs: ".Dumper(\@rows)."\n";
  #warn "row count is now: ".scalar @rows."\n";
  return @rows > 0 ? 1 : 0;

}


my @dirb = ();
sub test4 {

  #use Data::Dumper;
  vfsopendir(*DIR, "file:///tmp") or return 0;
  my @rows;
  while ( my $dir = <DIR> ){
    #warn "dirent: ".Dumper($dir)."\n";
    push(@rows, $dir->[-1]);
  }
  close DIR;
  @dirb = @rows;
  #warn "b dirs: ".Dumper(\@rows)."\n";
  #warn "row count is now: ".scalar @rows."\n";
  foreach (0..$#dira){
    #warn "$_: a($dira[$_]) diff b($dirb[$_]) \n" if $dira[$_] ne $dirb[$_];
    return 0 if $dira[$_] ne $dirb[$_];
  }
  foreach (0..$#dirb){
    #warn "$_: b($dirb[$_]) diff a($dira[$_]) \n" if $dira[$_] ne $dirb[$_];
    return 0 if $dira[$_] ne $dirb[$_];
  }
  return @rows > 0 ? 1 : 0;

}

