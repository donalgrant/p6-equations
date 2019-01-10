use v6;

use Globals;
use RPN;

class Solutions {
  
  has Numeric %.S{Str}=();  # solutions (keys are rpn strings, values are numeric for RPN)

  multi method new( @rpn_str ) { self.new( S=>@rpn_str.map({ RPN.new($_) }).grep({ $_.defined }).map({ (~$_,+$_) }) ) }

  multi method save(Any)      { self }  # nop in case an attempt to save undefined RPN
  multi method save(RPN $rpn) { %!S{~$rpn} = +$rpn if $rpn.defined; self }  # filter out invalid RPNs
  multi method save(Str $rpn) { self.save(RPN.new($rpn)) }
  
  multi method save(%rpn) { for %rpn<>:k  -> $r { self.save($r) }; self }
  multi method save(@rpn) { for @rpn      -> $r { self.save($r) }; self }

  method clear { %!S = (); self }

  method elems    { %!S.elems }
  method list     { %!S<>:k }
  method values   { %!S<>:v }
  method rpn_list { self.list.map({ RPN.new($_) }) }
  method found    { self.elems > 0 }

  method valid_for( $goal ) { self.list.grep({ %.S{$_}==$goal }) }
  
  method formable( Bag $all, Bag $req=Bag.new ) { self.rpn_list.grep({ ($_.Bag (<=) $all)           and ($_.Bag (>=) $req) }) }
  method one-away( Bag $all, Bag $req=Bag.new ) { self.rpn_list.grep({ ($_.Bag  (-) $all).total==1  and ($_.Bag (>=) $req) }) }

  method display { [gather { self.rpn_list.map({ take "{$_.aos}={+$_}" }) }].join('; ') }
}
