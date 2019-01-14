#!/usr/bin/env perl6

use v6;
use Test;

my $lib;

BEGIN { $lib=q{/Users/imel/gitdev/donalgrant/p6-equations/lib} }

use lib $lib;
use-ok 'Cube', "Make sure we can import the Cube.pm6 module";
use Cube;

use-ok 'Globals';
use Globals;

sub MAIN(
  :$verbose=False,       #= print extra diagnostic messages (default=False)
  :$debug,               #= comma separated list of debug labels (or 'all') (default none)
) {

  set_opt('verbose') if $verbose;
  if ($debug) { set_debug($_) for $debug.split(',') }
  
  my $f=qw<1 2 3 4 5 6>;

  my Cube $c .= new($f);
  my ($r, $b, $g, $k)=Red_Cube.new(), Blue_Cube.new(), Green_Cube.new(), Black_Cube.new();
  my Cube_Bag $cb .= new([$c,$r,$b,$g,$k]);

  subtest "Construction" => {
    given 'Cube'       { isa-ok $c, $_, $_ }
    given 'Red_Cube'   { isa-ok $r, $_, $_ }
    given 'Blue_Cube'  { isa-ok $b, $_, $_ }
    given 'Green_Cube' { isa-ok $g, $_, $_ } 
    given 'Black_Cube' { isa-ok $k, $_, $_ }
    given 'Cube_Bag'   { isa-ok $cb,$_, $_ }
  }

  subtest "Methods" => {
    for $c,$r,$b,$g,$k -> $cube {
      can-ok( $cube,  $_ ) for qw<new roll showing faces>;
    }
    can-ok( $cb, $_ ) for qw<new dice roll showing unique>;
  }

  subtest "Check Faces" => {
    is-deeply $c.faces.list.sort, $f.list.sort,  "Faces on cube match";
    like $f, /{ $c.showing }/,                   "showing matches one of the original faces";
    isa-ok $c.roll, 'Cube',                      "roll returns the object";
  }

  subtest "Roll Checks" => {
    for $c, $r, $b, $g, $k -> $cube {
      my %h=();
      %h{$cube.roll.showing}=1 for ^1000;             # 10,000 rolls should be enough to get at least one of each face
      is-deeply $cube.faces.list.sort, %h.keys.sort,  "All faces rolled after 10,000 tries";
      isa-ok $cube.roll, $cube.^name,                 "Roll returns the original object";
    }
  }

  subtest "Color Cube Faces" => {
    like $r.roll.showing, /<[0 1 2 3 + -]>/, "{$r.^name} face {$r.showing} matches expected for try $_" for ^10;
    like $b.roll.showing, /<[0 1 2 3 * /]>/, "{$b.^name} face {$b.showing} matches expected for try $_" for ^10;
    like $g.roll.showing, /<[4 5 6 ^ / -]>/, "{$g.^name} face {$g.showing} matches expected for try $_" for ^10;
    like $k.roll.showing, /<[7 8 9 @ / -]>/, "{$k.^name} face {$k.showing} matches expected for try $_" for ^10;
  }  

  done-testing;

  }
