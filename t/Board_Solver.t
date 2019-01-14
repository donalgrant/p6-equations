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
    my @methods=qw<new clear list calculate_solutions min_solution_cubes max_solution_cubes valid_solution doable_solution>;
    can-ok( Board_Solver.new(Board.new('')), $_ ) for @methods;
  }
  
  my $cube_list=qw{ 1 2 3 + };
  my Board $B .= new($cube_list);
  
  isa-ok($B, 'Board', "Board from $cube_list");
  
  my Board_Solver $BS .= new($B);
  
  subtest "Construction" => {
    isa-ok($BS,'Board_Solver',"Board_Solver from\n{$B.display}");
    dies-ok( { $B.calculate_solutions(5) }, "Attempt to Calculate Solutions on Board without goal should fail." );
  }
  
  subtest "goal analysis" => {
    $B.move_to_goal('3');
    
    lives-ok({ $BS.calculate_solutions(3) },"Can calculate a list of solutions; Board persists");
    
    ok $BS.list == qw{ 12+ 21+ }, "List of solutions for {$B.goal}";
    
    $BS.clear;
    is $BS.list, Empty, "Empty solution list";
  
    $B = Board.new(qw{ 1 2 2 3 3 3 8 + + - / * * ^ });
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
  
  done-testing;
}