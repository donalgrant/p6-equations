#!/usr/bin/env perl6

use v6;

my $lib;

BEGIN { $lib=q{/Users/imel/gitdev/donalgrant/p6-equations/lib} }

use Test;
use Math::Combinatorics :ALL;

use lib $lib;
use-ok 'Globals';
use Globals;

use-ok 'Tuples', "Make sure we can import the Globals.pm6 module";
use Tuples;

sub MAIN(
  :$verbose=False,       #= print extra diagnostic messages (default=False)
  :$debug,               #= comma separated list of debug labels (or 'all') (default none)
) {
  
  subtest "Combinatorics for a single list" => {
    my $x=(1,2,3);
  
    is-deeply variations($x,$x.elems), ( (1,2,3), (1,3,2), (2,1,3), (2,3,1), (3,1,2), (3,2,1) ), "Permutations of ({$x.join(',')})";
  
    is-deeply combinations($x,1), ( (1,), (2,), (3,) ),    "Combinations of ({$x.join(',')}) one at a time";
    is-deeply combinations($x,2), ( (1,2), (1,3), (2,3) ), "Combinations of ({$x.join(',')}) two at a time";
    is-deeply combinations($x,3), ( (1, 2, 3), ),           "Combinations of ({$x.join(',')}) three at a time";
  
    is-deeply variations($x,1), ( (1,), (2,), (3,) ),                                     "variations of ({$x.join(',')}) one at a time";
    is-deeply variations($x,2), ( (1,2), (1,3), (2,1), (2,3), (3,1), (3,2) ),             "variations of ({$x.join(',')}) two at a time";
    is-deeply variations($x,3), ( (1,2,3), (1,3,2), (2,1,3), (2,3,1), (3,1,2), (3,2,1) ), "variations of ({$x.join(',')}) three at a time";

    }

  subtest "Combinatorics for a list of lists" => {
  
    my $y=( (1,2), (2,3), (3,4) );
  
    is-deeply variations( $y, $y.elems ), ( ( (1,2),(2,3),(3,4) ),
  				            ( (1,2),(3,4),(2,3) ),
  				            ( (2,3),(1,2),(3,4) ),
  				            ( (2,3),(3,4),(1,2) ),
  				            ( (3,4),(1,2),(2,3) ),
  				            ( (3,4),(2,3),(1,2) ) ),    "Permutations of ({$y.map({ $_.join(',') }).join('),(')})";
  
    is-deeply combinations( $y,1 ), ( ( (1,2), ),
  	      		    	      ( (2,3), ),
  	      		      	      ( (3,4), ) ),		"Combinations of ({$y.map({ $_.join(',') }).join('),(')}) one at a time";
  
    is-deeply combinations( $y,2 ), ( ( (1,2),(2,3) ),
  	      		     	      ( (1,2),(3,4) ),
  	      		    	      ( (2,3),(3,4) ) ),	"Combinations of ({$y.map({ $_.join(',') }).join('),(')}) two at a time";
  
    is-deeply combinations( $y,3 ), ( ( (1,2),(2,3),(3,4) ), ),  "Combinations of ({$y.map({ $_.join(',') }).join('),(')}) three at a time";
  
    is-deeply variations( $y,1 ), ( ( (1,2), ),
  	      	      	   	( (2,3), ),
  	      			( (3,4), ) ),		  "variations of ({$y.map({ $_.join(',') }).join('),(')}) one at a time";
  
    is-deeply variations( $y,2 ), ( ( (1,2),(2,3) ),
  		       	        ( (1,2),(3,4) ),
  				( (2,3),(1,2) ),
  				( (2,3),(3,4) ),
  				( (3,4),(1,2) ),
  				( (3,4),(2,3) ) ),	  "variations of ({$y.map({ $_.join(',') }).join('),(')}) two at a time";
  
    is-deeply variations( $y,3 ), ( ( (1,2),(2,3),(3,4) ),
  				( (1,2),(3,4),(2,3) ),
  				( (2,3),(1,2),(3,4) ),
  				( (2,3),(3,4),(1,2) ),
  				( (3,4),(1,2),(2,3) ),
  				( (3,4),(2,3),(1,2) ) ),  "variations of ({$y.map({ $_.join(',') }).join('),(')}) three at a time";

  }

  subtest "Combinatorics for a list of single-element lists" => {
  
    my $z=( (1,), (2,), (3,) );
  
    is-deeply variations( $z, $z.elems ), ( ( (1,),(2,),(3,) ),
  	      		                    ( (1,),(3,),(2,) ),
  	      		                    ( (2,),(1,),(3,) ),
  	      		                    ( (2,),(3,),(1,) ),
  	      		                    ( (3,),(1,),(2,) ),
  	      		                    ( (3,),(2,),(1,) ) ),    "Permutations of ({$z.map({ $_.join(',') }).join('),(')})";
    
    is-deeply combinations( $z,1 ), ( ( (1,), ),
  	      		              ( (2,), ),
  	      		              ( (3,), ) ),           "Combinations of ({$z.map({ $_.join(',') }).join('),(')}) one at a time";
    
    is-deeply combinations( $z,2 ), ( ( (1,),(2,) ),
  	      		              ( (1,),(3,) ),
  	      		              ( (2,),(3,) ) ),        "Combinations of ({$z.map({ $_.join(',') }).join('),(')}) two at a time";
    
    is-deeply combinations( $z,3 ), ( ( (1,),(2,),(3,) ), ),  "Combinations of ({$z.map({ $_.join(',') }).join('),(')}) three at a time";
    
    is-deeply variations( $z,1 ), ( ( (1,), ),
  	      		        ( (2,), ),
  	      		        ( (3,), ) ), "variations of ({$z.map({ $_.join(',') }).join('),(')}) one at a time";
    
    is-deeply variations( $z,2 ), ( ( (1,),(2,) ),
  	      		        ( (1,),(3,) ),
  	      		        ( (2,),(1,) ),
  	      		        ( (2,),(3,) ),
  	      		        ( (3,),(1,) ),
  	      		        ( (3,),(2,) ) ), "variations of ({$z.map({ $_.join(',') }).join('),(')}) two at a time";
    
    is-deeply variations( $z,3 ), ( ( (1,),(2,),(3,) ),
  				( (1,),(3,),(2,) ),
  				( (2,),(1,),(3,) ),
  				( (2,),(3,),(1,) ),
  				( (3,),(1,),(2,) ),
  				( (3,),(2,),(1,) ) ), "variations of ({$z.map({ $_.join(',') }).join('),(')}) three at a time";
  
  }
  
  subtest "get_tuples" => {
    my $src=( 1, 2, 3, 4 );
    my $req=( 2, 3 );
    
    is-deeply get_tuples(1,$req.Bag,$src.Bag).sort, (), "req must be subset of src";
    is-deeply get_tuples(1,$src.Bag,$req.Bag).sort, (), "get_tuples one at a time";
    is-deeply get_tuples(2,$src.Bag,$req.Bag).sort,
    ( (2,3), (3,2) ).sort,                               "get_tuples two at a time";
    
    is-deeply get_tuples(3,$src.Bag,$req.Bag).sort,
    ( (1,2,3), (1,3,2), (2,1,3), (2,3,1), (3,1,2), (3,2,1),
      (2,3,4), (2,4,3), (3,2,4), (3,4,2), (4,2,3), (4,3,2) ).sort, "get_tuples three at a time";
    
    is-deeply get_tuples(4,$src.Bag,$req.Bag).sort,
    ( (1,2,3,4), (1,2,4,3), (1,3,2,4), (1,3,4,2),
      (1,4,2,3), (1,4,3,2), (2,1,3,4), (2,1,4,3),
      (2,3,1,4), (2,3,4,1), (2,4,1,3), (2,4,3,1),
      (3,1,2,4), (3,1,4,2), (3,2,1,4), (3,2,4,1),
      (3,4,1,2), (3,4,2,1), (4,1,2,3), (4,1,3,2),
      (4,2,1,3), (4,2,3,1), (4,3,1,2), (4,3,2,1) ).sort,           "get_tuples four at a time";
  }
  
  subtest "unique_tuples" => {
    is-deeply unique_tuples( ( (1,2,3), (1,3,2), (2,1,3), (1,3,2), (2,1,3) ) ).sort,
                             ( (1,2,3), (1,3,2), (2,1,3) ).sort,
  			       "unique_tuples removes duplicates";
  }
  
  done-testing;
}
