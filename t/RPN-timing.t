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

  sub timing-test(&calc_sub,$label,$nnum=5,$nops=4,$max=20000) {

    subtest $label => {
      my $t0=now.Real;
      my @pn=get_tuples $nnum, Bag.new((^10).roll($nnum)),              num_bag(Bag.new);  # no required cubes
      my @po=get_tuples $nops, Bag.new(qw{ + - * / ^  @ }.roll($nops)), ops_bag(Bag.new);  # no required cubes
      my @ops_slots=ops_slots($nops);
      my $n_solutions= @pn * @po * @ops_slots;    # numeric context -- product of array sizes
      diag "will be $n_solutions candidate RPNs generated";
      if ($n_solutions>$max) {
	my $reduce_factor=min( 4.0, ($n_solutions/$max)**(1.0/3.0) ); 
	my $nsl=max( 3, (+@ops_slots/$reduce_factor).floor ); 
	my $max_tuples=sqrt($max/@ops_slots).floor;
	my $npn=$max_tuples;
	my $npo=$max_tuples;
	@pn       =choose_n $npn, @pn;
	@po       =choose_n $npo, @po;
	@ops_slots=choose_n $nsl, @ops_slots;
	$n_solutions= @pn * @po* @ops_slots;
	diag "after sub-select, n_solutions=$n_solutions";
      }
      my $i=0;
      for @pn -> $pn {  
	for @po -> $po { 
	  for @ops_slots -> $slot {  # now construct this RPN
	    my $v=&calc_sub(num-ops-slot($pn,$po,$slot));  # could be undefined ('10/', etc)
	    diag "$pn, $po, $slot at count=$i / $n_solutions" if ++$i %% 5000;
	  }
	}
      }
      my $t=now.Real;
      diag "{($t-$t0).round(0.1)} seconds:  rate for $label ($nnum, $nops) was {($i/($t-$t0)).round} Hz";
    }
    
  }

#  for 1..3 { clear_RPN_Cache; timing-test(&rpn_value,    "time calc: iteration $_") }

  clear_RPN_Cache;
  for 1..8 {
    timing-test(&rpn_value, "cacheing with $_ ops", $_+1, $_);
  }
  
  done-testing;

}
