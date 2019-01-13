#!/usr/bin/env perl6

use v6;

use Algorithm::Combinatorics:from<Perl5> qw<tuples combinations permutations>;

my $lib;

BEGIN { $lib=q{/Users/imel/gitdev/donalgrant/p6-equations/lib} }

use Test;
use lib $lib;
use-ok 'Globals', "Make sure we can import the Globals.pm6 module";
use Globals;

subtest "Global Options" => {
  is opt, Empty,  "Start with empty option list";
  nok opt('test-1'), "option test-1 not yet set is Nil";
  nok opt('test-1'), "...even after the second check";
  
  set_opt('test-1');
  is opt('test-1'), True, "option 'test-1' set True";
  set_opt( qw{ test-2 test-3 test-4 } );
  is opt('test-3'), True, "option 'test-3' set True";
  clr_opt('test-1','test-2','test-3','test-4');
  nok opt('test-3'), "options cleared";
  set_opt('test-1','test-2','test-3','test-4');
  set_opt('test-3');
  is opt('test-3'), True, "setting 'test-3' again doesn't change it";
  set_opt( t1=>True, t2=>False, t3=>4, t4=>'Blue' );
  ok opt.keys.sort == qw{ test-1 test-2 test-3 test-4 t1 t2 t3 t4 }.sort, "options set so far";
  is opt('t2'), False,  "Setting option to False works";
  is opt('t4'), 'Blue', "Setting option to a string works";
  clr_opt('t4');
  nok opt('t4'),  "Clearing an option sets it to Nil";
  clr_opt('t2');
  ok opt.keys.sort == qw{ test-1 test-2 test-3 test-4 t1 t3 }, "two options removed";
  clr_opt;
  is opt, Empty, "all options cleared";
}

subtest "debug labels" => {
  is debug, Empty,  "Start with empty debug list";
  nok debug('test-1'), "debug label test-1 not yet set is Nil";
  nok debug('test-1'), "...even after the second check";
  set_debug('test-1');
  is debug('test-1'), True, "debug label 'test-1' set True";
  set_debug( qw{ test-2 test-3 test-4 } );
  is debug('test-3'), True, "debug label 'test-3' set True";
  clr_debug('test-1','test-2','test-3','test-4');
  nok debug('test-3'), "debug label cleared";
  set_debug('test-1','test-2','test-3','test-4');
  set_debug('test-3');
  is debug('test-3'), True, "setting 'test-3' again doesn't change it";
  set_debug( t1=>True, t2=>False, t3=>4, t4=>'Blue' );
  ok debug.sort == qw{ test-1 test-2 test-3 test-4 t1 t2 t3 t4 }.sort, "debug labels set so far";
  is debug('t2'), False,  "Setting debug label to False works";
  is debug('t4'), 'Blue', "Setting debug label to a string works";
  clr_debug('t4');
  nok debug('t4'),  "Clearing a debug label sets it to Nil";
  ok debug_all('t1','t3'), "logical and for debug labels";
  ok debug_all('t1','t2','t3'), "logical and, with one label False (but not Nil)";
  nok debug_all('t1','t4'),     "logical and, with one label missing";
  ok debug_any('t1','t4'),      "logical any, with one label missing";
  nok debug_any,                "logical any, with no arguments";
  ok debug_all,                 "logical all, with no arguments (no Nils)";
  clr_debug('t2');
  ok debug.sort == qw{ test-1 test-2 test-3 test-4 t1 t3 }, "two debug labels removed";
  clr_debug;
  is debug, Empty, "all debug labels cleared";
  nok debug('t1'), "confirm debug label is cleared";
  set_debug('all');
  ok debug('t1'), "any label is set to true if 'all' debug label is set";
  clr_debug;
}

lives-ok { say caller.list.join('') }, "caller";

subtest "debug_fn" => {
  sub caller_test() {
    debug_fn() ?? "triggering message" !! Nil;
  }

  nok caller_test, "debug_fn doesn't trigger";
  set_debug('caller_test');
  is caller_test, "triggering message", "debug_fn triggers";
}

subtest "msg tests" => {
  lives-ok { msg("test message") }, "test message";
  lives-ok { msg("test", "src")  }, "test message with source";
  lives-ok { msg("test", :trace) }, "test message with trace";
  lives-ok { msg("test", "src", :trace) }, "test message with source and trace";
}

subtest "quit tests" => {
  dies-ok  { quit("quit test")   }, "quit test";
  dies-ok  { quit("quit", "src") }, "quit test with source";
}

subtest "assert tests" => {
  lives-ok { assert( { 1 }, "pass test") }, "assert with pass";
  dies-ok  { assert( { 0 }, "fail test") }, "assert with fail";
}

subtest "verify built-in list operations" => {
  ok( unique(qw<a b b b c c >) == [ qw<a b c> ], "unique" );  # built in to Perl 6

  my @list=qw{ a b c d e 1 2 3 4 5 };
  my @original_list=@list;
  my @shuffled=shuffle(@list);  # make a copy
  
  ok(  @list.elems    ==  @shuffled.elems, "shuffle preserves array length" );
  ok(  @shuffled      ==  @list,           "shuffle retains all elements" );
  nok( @list          eqv @shuffled,       "shuffle altered the order of the list.  (fail should be rare.)" );
  ok(  @original_list eqv @list,           "shuffle didn't alter the order of original list." );


  is( min(5,9,3,234,-2,0,3), -2,   "min on array" );
  is( max(5,9,3,234,-2,0,3), 234,  "max on array" );
}

subtest "chance tests" => {
  my $x=0;
  my $y=0;
  for (^10000) { $x++ if chance(0.1); $y++ if chance(0.8) }
  
  ok( 800 <= $x <= 1200, "Odds are reasonable ($x out of 10000) for 10% chance" );
  ok( 7500 <= $y <= 8500, "Odds are reasonable ($y out of 10000) for 80% chance" );
}

subtest "Combinatorics" => {
  my $x=(1,2,3);
  my @x=[1,2,3];

  is-deeply p5-deref1(permutations($x)), [ [1,2,3], [1,3,2], [2,1,3], [2,3,1], [3,1,2], [3,2,1] ], "Permutations of ({$x.join(',')})";
  is-deeply p5-deref1(permutations(@x)), [ [1,2,3], [1,3,2], [2,1,3], [2,3,1], [3,1,2], [3,2,1] ], "Permutations of [{@x.join(',')}]";

  is-deeply p5-deref1(combinations($x,1)), [ [1], [2], [3] ],       "Combinations of ({$x.join(',')}) one at a time";
  is-deeply p5-deref1(combinations($x,2)), [ [1,2], [1,3], [2,3] ], "Combinations of ({$x.join(',')}) two at a time";
  is-deeply p5-deref1(combinations($x,3)), [ (1,), (2,), (3,) ],    "Combinations of ({$x.join(',')}) three at a time";

  is-deeply p5-deref1(combinations(@x,1)), [ [1], [2], [3] ],       "Combinations of [{$x.join(',')}] one at a time";
  is-deeply p5-deref1(combinations(@x,2)), [ [1,2], [1,3], [2,3] ], "Combinations of [{$x.join(',')}] two at a time";
  is-deeply p5-deref1(combinations(@x,3)), [ (1,), (2,), (3,) ],    "Combinations of [{$x.join(',')}] three at a time";

  is-deeply p5-deref1(tuples($x,1)), [ [1], [2], [3] ],                                        "tuples of ({$x.join(',')}) one at a time";
  is-deeply p5-deref1(tuples($x,2)), [ [1,2], [1,3], [2,1], [2,3], [3,1], [3,2] ],             "tuples of ({$x.join(',')}) two at a time";
  is-deeply p5-deref1(tuples($x,3)), [ [1,2,3], [1,3,2], [2,1,3], [2,3,1], [3,1,2], [3,2,1] ], "tuples of ({$x.join(',')}) three at a time";

  is-deeply p5-deref1(tuples(@x,1)), [ [1], [2], [3] ],                                        "tuples of [{$x.join(',')}] one at a time";
  is-deeply p5-deref1(tuples(@x,2)), [ [1,2], [1,3], [2,1], [2,3], [3,1], [3,2] ],             "tuples of [{$x.join(',')}] two at a time";
  is-deeply p5-deref1(tuples(@x,3)), [ [1,2,3], [1,3,2], [2,1,3], [2,3,1], [3,1,2], [3,2,1] ], "tuples of [{$x.join(',')}] three at a time";

  my @y=[ [1,2], [2,3], [3,4] ];

  is-deeply p5-deref2(permutations( @y )), [ [ [1,2],[2,3],[3,4] ],
					     [ [1,2],[3,4],[2,3] ],
					     [ [2,3],[1,2],[3,4] ],
					     [ [2,3],[3,4],[1,2] ],
					     [ [3,4],[1,2],[2,3] ],
					     [ [3,4],[2,3],[1,2] ] ],    "Permutations of [{@y.map({ $_.join(',') }).join('],[')}]";

  is-deeply p5-deref2(combinations( @y,1 )), [ [ [1,2], ],
					       [ [2,3], ],
					       [ [3,4], ] ],"Combinations of [{@y.map({ $_.join(',') }).join('],[')}] one at a time";

  is-deeply p5-deref2(combinations( @y,2 )), [ [ [1,2],[2,3] ],
					       [ [1,2],[3,4] ],
					       [ [2,3],[3,4] ] ],        "Combinations of [{@y.map({ $_.join(',') }).join('],[')}] two at a time";

  is-deeply p5-deref1(combinations( @y,3 )), [ [ [1,2],[2,3],[3,4] ] ],  "Combinations of [{@y.map({ $_.join(',') }).join('],[')}] three at a time";

  is-deeply p5-deref2(tuples( @y,1 )), [ [ [1,2], ],
					 [ [2,3], ],
					 [ [3,4], ] ], "tuples of [{@y.map({ $_.join(',') }).join('],[')}] one at a time";

  is-deeply p5-deref2(tuples( @y,2 )), [ [ [1,2],[2,3] ],
					 [ [1,2],[3,4] ],
					 [ [2,3],[1,2] ],
					 [ [2,3],[3,4] ],
					 [ [3,4],[1,2] ],
					 [ [3,4],[2,3] ] ], "tuples of [{@y.map({ $_.join(',') }).join('],[')}] two at a time";

  is-deeply p5-deref2(tuples( @y,3 )), [ [ [1,2],[2,3],[3,4] ],
					 [ [1,2],[3,4],[2,3] ],
					 [ [2,3],[1,2],[3,4] ],
					 [ [2,3],[3,4],[1,2] ],
					 [ [3,4],[1,2],[2,3] ],
					 [ [3,4],[2,3],[1,2] ] ], "tuples of [{@y.map({ $_.join(',') }).join('],[')}] three at a time";
  

  my @z=[ [1,], [2,], [3,] ];

  is-deeply p5-deref2(permutations( @z )), [ [ [1,],[2,],[3,] ],
					     [ [1,],[3,],[2,] ],
					     [ [2,],[1,],[3,] ],
					     [ [2,],[3,],[1,] ],
					     [ [3,],[1,],[2,] ],
					     [ [3,],[2,],[1,] ] ],    "Permutations of [{@z.map({ $_.join(',') }).join('],[')}]";
  
  is-deeply p5-deref2(combinations( @z,1 )), [ [ [1,], ],
					       [ [2,], ],
					       [ [3,], ] ],"Combinations of [{@z.map({ $_.join(',') }).join('],[')}] one at a time";
  
  is-deeply p5-deref2(combinations( @z,2 )), [ [ [1,],[2,] ],
					       [ [1,],[3,] ],
					       [ [2,],[3,] ] ],        "Combinations of [{@z.map({ $_.join(',') }).join('],[')}] two at a time";
  
  is-deeply p5-deref1(combinations( @z,3 )), [ [ [1,],[2,],[3,] ] ],  "Combinations of [{@z.map({ $_.join(',') }).join('],[')}] three at a time";
  
  is-deeply p5-deref2(tuples( @z,1 )), [ [ [1,], ],
					 [ [2,], ],
					 [ [3,], ] ], "tuples of [{@z.map({ $_.join(',') }).join('],[')}] one at a time";
  
  is-deeply p5-deref2(tuples( @z,2 )), [ [ [1,],[2,] ],
					 [ [1,],[3,] ],
					 [ [2,],[1,] ],
					 [ [2,],[3,] ],
					 [ [3,],[1,] ],
					 [ [3,],[2,] ] ], "tuples of [{@z.map({ $_.join(',') }).join('],[')}] two at a time";
  
  is-deeply p5-deref2(tuples( @z,3 )), [ [ [1,],[2,],[3,] ],
					 [ [1,],[3,],[2,] ],
					 [ [2,],[1,],[3,] ],
					 [ [2,],[3,],[1,] ],
					 [ [3,],[1,],[2,] ],
					 [ [3,],[2,],[1,] ] ], "tuples of [{@z.map({ $_.join(',') }).join('],[')}] three at a time";

}

subtest "ops_slots" => {
  is ops_slots(1).sort, ['1'].sort,                                        "ops slot for 1";
  is ops_slots(2).sort, ['11','02'].sort,                                  "ops slots for 2";
  is ops_slots(3).sort, ['111','102','021','012','003'].sort,              "ops slots for 3";
  is ops_slots(4).sort, ['1111','1102','1021','1012',	         
			 '1003','0211','0202','0121','0112',	         
			 '0103','0031','0022','0013','0004'].sort,         "ops slots for 4";
  is ops_slots(5).sort, ['11111','11102',
			 '11021','11012','11003','10211','10202',
			 '10121','10112','10103','10031','10022','10013',
			 '10004','02111','02102','02021','02012',
			 '02003','01211','01202','01121','01112',
			 '01103','01031','01022','01013','01004','00311',
			 '00302','00221','00212','00203','00131','00122',
			 '00113','00104','00041','00032','00023','00014',
			 '00005'].sort,                                    "ops slots for 5";
  
  is num-ops-slot(qw{ 2 3 4 },qw{ + * },'02'), '234+*', "Create an RPN from three nums and two ops";
  is num-ops-slot(qw{ 2 3 4 },qw{ + * },'11'), '23+4*', "Create an RPN from three nums and two ops, alternate slotting";
}

subtest "choose_n" => {
  ok choose_n(3,[ ^6 ])           (<=) [ ^6 ], "choose_n generates a subset of the source";
  ok choose_n([ ^6 ].elems,[ ^6 ]) ==  [ ^6 ], "choose_n can select the entire set";
  is-deeply choose_n(100,[ ^6 ]),      [ ^6 ], "choose_n returns original set if n out of range";
  dies-ok { choose_n(0,[ ^6 ]) },              "choose_n fails on n < 1";
}

subtest "get_tuples" => {
  my $src=[ 1..4 ];
  my $req=[ 2, 3 ];
  
  is-deeply get_tuples(1,$req.Bag,$src.Bag).sort, (),           "req must be subset of src";
  is-deeply get_tuples(1,$src.Bag,$req.Bag).sort, (),           "get_tuples one at a time";
  is-deeply get_tuples(2,$src.Bag,$req.Bag).sort,
  [ [2,3], [3,2] ].sort,                                         "get_tuples two at a time";
  
  is-deeply get_tuples(3,$src.Bag,$req.Bag).sort,
  [ [1,2,3], [1,3,2], [2,1,3], [2,3,1], [3,1,2], [3,2,1],
    [2,3,4], [2,4,3], [3,2,4], [3,4,2], [4,2,3], [4,3,2] ].sort, "get_tuples three at a time";
  
  is-deeply get_tuples(4,$src.Bag,$req.Bag).sort,
  [ [1,2,3,4], [1,2,4,3], [1,3,2,4], [1,3,4,2],
    [1,4,2,3], [1,4,3,2], [2,1,3,4], [2,1,4,3],
    [2,3,1,4], [2,3,4,1], [2,4,1,3], [2,4,3,1],
    [3,1,2,4], [3,1,4,2], [3,2,1,4], [3,2,4,1],
    [3,4,1,2], [3,4,2,1], [4,1,2,3], [4,1,3,2],
    [4,2,1,3], [4,2,3,1], [4,3,1,2], [4,3,2,1] ].sort,           "get_tuples four at a time";
}

subtest "unique_tuples" => {
  is-deeply unique_tuples( [ [1,2,3], [1,3,2], [2,1,3], [1,3,2], [2,1,3] ] ).sort,
                           [ [1,2,3], [1,3,2], [2,1,3] ].sort,
			   "unique_tuples removes duplicates";
}

done-testing;
