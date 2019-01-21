use v6;

use Globals;
use RPN;

role Solutions {
  
  has Numeric %.S{Str}=();  # solutions (keys are rpn strings, values are numeric for RPN)

  multi method save(Any)      { self }  # nop in case an attempt to save undefined RPN
  multi method save(RPN $rpn) { %!S{$rpn.Str} = $rpn.Numeric if $rpn.defined; self }  # filter out invalid RPNs
  multi method save(Str $rpn) { self.save(rpn($rpn)) }
  
  multi method save(%rpn) { for %rpn<>:k  -> $r { self.save($r) }; self }
  multi method save(@rpn) { for @rpn      -> $r { self.save($r) }; self }

  method clear            { %!S = (); self }
  
  multi method delete(Str $rpn) { %.S{$rpn}:delete; self }
  multi method delete(RPN $rpn) { self.delete($rpn.Str); self }

  method elems    { %!S.elems }
  method list     { %!S<>:k }
  method values   { %!S<>:v }
  method rpn_list { self.list.map({ RPN.new($_) }) }
  method found    { self.elems > 0 }

  method valid_for( $goal ) { self.list.grep({ %.S{$_}==$goal }) }
  
  method formable( Bag $all, Bag $req=Bag.new ) { self.rpn_list.grep({ ($_.Bag ⊆ $all)           and ($_.Bag ⊇ $req) }) }
  method one-away( Bag $all, Bag $req=Bag.new ) { self.rpn_list.grep({ ($_.Bag ∖ $all).total==1  and ($_.Bag ⊇ $req) }) }

  method display { [gather { self.rpn_list.map({ take "{$_.aos}={+$_}" }) }].join('; ') }
}
