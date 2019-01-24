#!/usr/bin/env perl6

use v6;
use Test;

my $lib;

BEGIN { $lib=q{/Users/imel/gitdev/donalgrant/p6-equations/lib} }

use lib $lib;

use-ok 'Board_Solver';
use Board_Solver;
use Board;
use RPN;

use-ok 'Globals';
use Globals;

sub MAIN(
  :$verbose=False,       #= print extra diagnostic messages (default=False)
  :$debug,               #= comma separated list of debug labels (or 'all') (default none)
) {

  set_opt('verbose') if $verbose;
  if ($debug) { set_debug($_) for $debug.split(',') }

  subtest "methods" => {
    my @methods=qw<new clear list calculate_solutions min_solution_cubes max_solution_cubes valid_solution doable_solution find_goal>;
    can-ok( Board_Solver.new(board('')), $_ ) for @methods;
  }
  
  my $cube_list=qw{ 1 2 3 + };
  my Board $B .= new($cube_list);
  
  isa-ok($B, 'Board', "Board from $cube_list");
  
  my Board_Solver $BS .= new($B);
  
  subtest "Construction" => {
    isa-ok($BS,'Board_Solver',"Board_Solver from\n{$B.display}");
    dies-ok( { $B.calculate_solutions(5) }, "Attempt to Calculate Solutions on Board without goal should fail." );

    isa-ok(board_solver($B), 'Board_Solver', "board_solver construction sub");
  }
  
  subtest "goal analysis" => {
    $B.move_to_goal('3');
    
    lives-ok({ $BS.calculate_solutions(3) },"Can calculate a list of solutions; Board persists");
    
    ok $BS.list == qw{ 12+ 21+ }, "List of solutions for {$B.goal}";
    
    $BS.clear;
    is $BS.list, Empty, "Empty solution list";
  
    $B = board(qw{ 1 2 2 3 3 3 8 + + - / * * ^ });
    $B.move_to_goal('8');
    $B.move_to_required($_)  for qw{ 1 2 2 * };
    $B.move_to_permitted($_) for qw{ 3 };
    $B.move_to_forbidden($_) for qw{ / };
    
    $BS = Board_Solver.new($B);
    
    msg $B.display;
  
    is $BS.min_solution_cubes, 5,  "min solution cubes correct";       
    is $BS.max_solution_cubes, 11, "max solution cubes correct";
    
    ok  $BS.valid_solution( RPN.new('8') ), 'check identity solution for validity';
    ok  $BS.valid_solution( RPN.new('222**') ), 'unavailable solution can still be valid';
    nok $BS.valid_solution( RPN.new('22*') ), 'available solution may also be invalid';
    
    ok  $BS.valid_solution(  RPN.new('23^1/') ),       'valid solution from existing (but forbidden) cubes';
    nok $BS.doable_solution( RPN.new('23^1/') ),       'unavaible solution even though cubes exist and valid';
    
    ok  $BS.valid_solution(  RPN.new('23^') ), 'solution violating required cubes can be valid';
    nok $BS.doable_solution( RPN.new('23^') ), 'solution violating required cubes is not doable';
    
    ok  $BS.cubes-missing_for( RPN.new('252-^') ) == qw{ 5 }.Bag, "solution with cubes which aren't available";
  
    my RPN $rpn .= new('231*^33-2*+');
  
    ok  $BS.valid_solution(  $rpn ), 'complicated but valid solution';
    ok  $BS.doable_solution( $rpn ), 'complicated but doable solution';
    
    ok  $BS.cubes-to-go_for( $rpn ) == qw{ 3 3 * - + ^ }.Bag, "cubes to go for $rpn";
    
    nok $BS.go-out_check( $rpn ),    "can't go out with $rpn yet";
  
    $B.move_to_permitted($_) for qw{ 3 3 * - + };
    msg $B.display;
  
    is  $BS.go-out_check( $rpn ), '^', "one cube from solution for $rpn";
    nok $BS.on-board_solution( $rpn ), "which means it's not on the board yet";
  
    $B.move_to_required($_) for qw{ ^ };
    msg $B.display;
    ok  $BS.on-board_solution($rpn),   "now it's a solution on the board";
    is  $BS.go-out_check($rpn), '',    "and go-out check passes with empty cube returned";
  }

  subtest "Choose Goal" => {

    my $B=board(Bag.new(qw{1 2 2 3 -}));
    my $g=board_solver($B).find_goal;

    is( $g, 1, "Only one goal possible");

    ok( find_goal(board(Bag.new(qw{ 1 2 3 4 5 6 7 8 9 - + * / ^ @ }))).defined, "Found a goal on a larger board" );
    is( find_goal(board(Bag.new(qw{ - * - + / }))),      Nil,                   "No goal possible: no numbers");
    is( find_goal(board(Bag.new(qw{ 1 - + / }))),        Nil,                   "No goal possible: single digit");
    is( find_goal(board(Bag.new(qw{ 1 2 3 * / }))),      Nil,                   "No goal possible: cannot construct" );
    is( find_goal(board(Bag.new(qw{ 1 2 1 2 * / })), max_digits=>1), Nil,       "No goal possible: 1 digit, no singletons" );

  }
  
  subtest "non-integer goals" => {

    my ($B, @r);
    
    $B=Board.new(G=>'1/3',U=>BagHash.new('2','6','/'));
    diag $B.display;
    @r=board_solver($B).solve.list;
    is-deeply( @r, [ '26/' ], "rational goal" );
    
    $B=Board.new(G=>'1/4',U=>BagHash.new('2','8','/'));
    diag $B.display;
    @r=board_solver($B).solve.list;
    is-deeply( @r, [ '28/' ], "rational goal with terminating decimal" );
  }
  
  subtest "find_replacement for digits" => {

    for ^8 -> $digit {
      my $rpn=rpn($digit~'1+');
      my $B=Board.new(G=>($digit.Int+1).Str,F=>BagHash.new($digit),U=>BagHash.new('1','2','+','-',($digit+2).Str));
      my BagHash $missing .= new($digit.Str);
      my @r = find_replacement($B,$missing,$rpn);
      if ($digit==2) {
	is-deeply(@r, [], "Don't replace $digit with 2" );
      } else {
	is-deeply(@r,[ ($digit+2).Str~'2-1+' ], "Replace digit $digit" );
      }
    }

    with 8 -> $digit {
      my $rpn=rpn($digit~'1+');
      my $B=Board.new(G=>($digit.Int+1).Str,F=>BagHash.new($digit),U=>BagHash.new('1','2','4','+','*'));
      my BagHash $missing .= new($digit.Str);
      my @r = find_replacement($B,$missing,$rpn);
      is-deeply(@r.sort,[ '24*1+', '42*1+' ].sort, "Replace digit $digit, symmetric product" );
    }

    with 9 -> $digit {
      my $rpn=rpn($digit~'1+');
      my $B=Board.new(G=>($digit.Int+1).Str,F=>BagHash.new($digit),U=>BagHash.new('1','3','3','+','*'));
      my BagHash $missing .= new($digit.Str);
      my @r = find_replacement($B,$missing,$rpn);
      is-deeply(@r.sort,[ '33*1+' ].sort, "Replace digit $digit, symmetric product, unique" );
    }
  }

  subtest "find_replacement for operators" => {

    my ($rpn, $B, @r);
    my BagHash $missing;

    $rpn=rpn('21+');
    $B=Board.new(G=>'3',F=>BagHash.new(qw{ + }),U=>BagHash.new(qw{ 0 1 2 - - }));
    $missing .= new(qw{ + });
    @r = find_replacement($B,$missing,$rpn);
    is-deeply(@r,[qw{ 201-- 102-- }], "Replace +" );

    $rpn=rpn('24*');
    $B=Board.new(G=>'8',F=>BagHash.new(qw{ * }),U=>BagHash.new(qw{ 1 2 4 / / }));
    $missing .= new(qw{ * });
    @r = find_replacement($B,$missing,$rpn);
    is-deeply(@r,[qw{ 214// 412// }], "Replace *" );

    $rpn=rpn('23*');
    $B=Board.new(G=>'6',F=>BagHash.new(qw{ * }),U=>BagHash.new(qw{ 1 2 3 / / }));
    $missing .= new(qw{ * });
    @r = find_replacement($B,$missing,$rpn);
    is-deeply(@r,[qw{ 213// 312// }], "Replace * with rational replace-goal" );

    $rpn=rpn('23^');
    $B=Board.new(G=>'8',F=>BagHash.new(qw{ ^ }),U=>BagHash.new(qw{ 1 2 3 / @ }));
    $missing .= new(qw{ ^ });
    @r = find_replacement($B,$missing,$rpn);
    is-deeply(@r,[qw{ 13/2@ }], "Replace ^ with rational replace-goal" );

    $rpn=rpn('24^');
    $B=Board.new(G=>'16',F=>BagHash.new(qw{ ^ }),U=>BagHash.new(qw{ 1 2 4 / @ }));
    $missing .= new(qw{ ^ });
    @r = find_replacement($B,$missing,$rpn);
    is-deeply(@r,[qw{ 14/2@ }], "Replace ^ with replace-goal" );

    $rpn=rpn('38@');
    $B=Board.new(G=>'2',F=>BagHash.new(qw{ @ }),U=>BagHash.new(qw{ 1 3 8 / ^ }));
    $missing .= new(qw{ @ });
    @r = find_replacement($B,$missing,$rpn);
    is-deeply(@r,[qw{ 813/^ }], "Replace @ with rational replace-goal" );

    $rpn=rpn('24@');
    $B=Board.new(G=>'2',F=>BagHash.new(qw{ @ }),U=>BagHash.new(qw{ 1 2 4 / ^ }));
    $missing .= new(qw{ @ });
    @r = find_replacement($B,$missing,$rpn);
    is-deeply(@r,[qw{ 412/^ }], "Replace @" );

    $rpn=rpn('30^');
    $B=Board.new(G=>'1',F=>BagHash.new(qw{ ^ }),U=>BagHash.new(qw{ 0 1 3 / @ }));
    $missing .= new(qw{ ^ });
    @r = find_replacement($B,$missing,$rpn);
    is-deeply(@r,[], "Replace ^ passes divide-by-zero check" );

    $rpn=rpn('30*');
    $B=Board.new(G=>'0',F=>BagHash.new(qw{ * }),U=>BagHash.new(qw{ 0 1 3 / / }));
    $missing .= new(qw{ * });
    @r = find_replacement($B,$missing,$rpn);
    is-deeply(@r,[ '013//' ], "Replace * passes divide-by-zero check, returns remaining solution" );
  }
  
  done-testing;
}
