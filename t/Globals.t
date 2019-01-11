#!/usr/bin/env perl6

use v6;

use Algorithm::Combinatorics:from<Perl5> qw<tuples combinations permutations>;

my $lib;

BEGIN { $lib=q{/Users/imel/gitdev/donalgrant/p6-equations/lib} }

use Test;
use lib $lib;
use-ok 'Globals', "Make sure we can import the Globals.pm6 module";
use Globals;

lives-ok { say caller.list.join('') }, "caller";

lives-ok { msg("test message") }, "test message";
lives-ok { msg("test", "src")  }, "test message with source";
lives-ok { msg("test", :trace) }, "test message with trace";
lives-ok { msg("test", "src", :trace) }, "test message with source and trace";

dies-ok  { quit("quit test")   }, "quit test";
dies-ok  { quit("quit", "src") }, "quit test with source";

lives-ok { assert( { 1 }, "pass test") }, "assert with pass";
dies-ok  { assert( { 0 }, "fail test") }, "assert with fail";

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

my $x=0;
my $y=0;
for (^10000) { $x++ if chance(0.1); $y++ if chance(0.8) }

ok( 800 <= $x <= 1200, "Odds are reasonable ($x out of 10000) for 10% chance" );
ok( 7500 <= $y <= 8500, "Odds are reasonable ($y out of 10000) for 80% chance" );

# need tests for combinatorics / get_tuples

$x=(1,2,3);
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

ok choose_n(3,[ ^6 ])           (<=) [ ^6 ], "choose_n generates a subset of the source";
ok choose_n([ ^6 ].elems,[ ^6 ]) ==  [ ^6 ], "choose_n can select the entire set";
is-deeply choose_n(100,[ ^6 ]),      [ ^6 ], "choose_n returns original set if n out of range";
dies-ok { choose_n(0,[ ^6 ]) },              "choose_n fails on n < 1";

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

# need tests for unique_tuples

is-deeply unique_tuples(
  [ [1,2,3], [1,3,2], [2,1,3], [1,3,2], [2,1,3] ]
                              ).sort,
  [ [1,2,3], [1,3,2], [2,1,3] ].sort,               "unique_tuples removes duplicates";


done-testing;
