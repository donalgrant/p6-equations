#!/usr/bin/env perl6

use v6;
use Test;

my $lib;

BEGIN { $lib=q{/Users/imel/gitdev/donalgrant/p6-equations/lib} }

use lib $lib;
use-ok 'RPN';
use RPN;

use-ok 'Globals';
use Globals;

sub MAIN(
  :$verbose=False,       #= print extra diagnostic messages (default=False)
  :$debug,               #= comma separated list of debug labels (or 'all') (default none)
) {

  set_opt('verbose') if $verbose;
  if ($debug) { set_debug($_) for $debug.split(',') }

  diag "generate RPN set for timing test";

  sub timing-test(&calc_sub,$label,$nnum=4,$nops=3) {

    subtest $label => {
      my $t0=now.Real;
      my @pn=get_tuples $nnum, Bag.new((^10).roll($nnum)),         num_bag(Bag.new);  # no required cubes
      my @po=get_tuples $nops, Bag.new(qw{ + - * / @ ^ }.roll(5)), ops_bag(Bag.new);  # no required cubes
      my @ops_slots=ops_slots($nops);
      my $n_solutions= @pn * @po * @ops_slots;    # numeric context -- product of array sizes
      diag "will be $n_solutions candidate RPNs generated";
      my $i=0;
      for @pn -> $pn {  
	for @po -> $po { 
	  for @ops_slots -> $slot {  # now construct this RPN
	    my $v=&calc_sub(num-ops-slot($pn,$po,$slot));  # could be undefined ('10/', etc)
	    diag "$pn, $po, $slot at count=$i / $n_solutions" if ++$i %% 5000;
	  }
	}
      }
      diag "execution rate for $label was {(now.Real-$t0)/($n_solutions/1000)} kHz";
    }
    
  }

  timing-test(&rpn_value-new,'time calc2 (1)');
  timing-test(&rpn_value,'time calc1 (1)');
  timing-test(&rpn_value-new,'time calc2 (2)');
  timing-test(&rpn_value,'time calc1 (2)');
  
  done-testing;

}
