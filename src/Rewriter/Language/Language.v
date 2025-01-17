Require Import Coq.ZArith.ZArith.
Require Import Coq.FSets.FMapPositive.
Require Import Coq.Bool.Bool.
Require Import Coq.Lists.List.
Require Import Coq.Classes.Morphisms.
Require Import Coq.Relations.Relation_Definitions.
Require Import Rewriter.Language.PreCommon.
Require Import Rewriter.Util.LetIn.
Require Import Rewriter.Util.ListUtil.
Require Import Rewriter.Util.Option.
Require Import Rewriter.Util.OptionList.
Require Import Rewriter.Util.Prod.
Require Import Rewriter.Util.NatUtil.
Require Import Rewriter.Util.CPSNotations.
Require Import Rewriter.Util.Bool.Reflect.
Require Import Rewriter.Util.Bool.
Require Import Rewriter.Util.ListUtil.
Require Import Rewriter.Util.Prod.
Require Import Rewriter.Util.Notations.
Import Coq.Lists.List ListNotations.
Export Language.PreCommon.

Local Set Primitive Projections.

Import EqNotations.
Module Compilers.
  Export Language.PreCommon.
  Local Set Boolean Equality Schemes.
  Local Set Decidable Equality Schemes.
  Module type.
    Inductive type {base_type : Type} := base (t : base_type) | arrow (s d : type).
    Global Arguments type : clear implicits.

    Lemma reflect_type_beq {base_type} {base_beq} {reflect_base_beq : reflect_rel (@eq base_type) base_beq} : reflect_rel (@eq (type base_type)) (@type_beq base_type base_beq).
    Proof.
      apply reflect_of_beq; (apply internal_type_dec_bl + apply internal_type_dec_lb); apply reflect_to_beq; assumption.
    Defined.
    Global Hint Extern 1 (reflect (@eq (type ?base_type) ?x ?y) _) => notypeclasses refine (@reflect_type_beq base_type _ _ x y) : typeclass_instances.

    Fixpoint count_args {base_type} (t : type base_type) : nat
      := match t with
         | base _ => O
         | arrow _ d => S (count_args d)
         end.

    Fixpoint final_codomain {base_type} (t : type base_type) : base_type
      := match t with
         | base t
           => t
         | arrow s d => @final_codomain base_type d
         end.

    Fixpoint uncurried_domain {base_type} prod s (t : type base_type) : type base_type
      := match t with
         | base t
           => s
         | arrow s' d => @uncurried_domain base_type prod (prod s s') d
         end.

    Fixpoint for_each_lhs_of_arrow {base_type} (f : type base_type -> Type) (t : type base_type) : Type
      := match t with
         | base t => unit
         | arrow s d => f s * @for_each_lhs_of_arrow _ f d
         end.

    Fixpoint forall_each_lhs_of_arrow {base_type} {F : type base_type -> Type} (f : forall t, F t) {t : type base_type}
      : for_each_lhs_of_arrow F t
      := match t with
         | base t => tt
         | arrow s d => (f s, @forall_each_lhs_of_arrow _ F f d)
         end.

    Fixpoint andb_each_lhs_of_arrow {base_type} (f : type base_type -> bool) (t : type base_type) : bool
      := match t with
         | base t => true
         | arrow s d => andb (f s) (@andb_each_lhs_of_arrow _ f d)
         end.

    (** Denote [type]s into their interpretation in [Type]/[Set] *)
    Fixpoint interp {base_type} (base_interp : base_type -> Type) (t : type base_type) : Type
      := match t with
         | base t => base_interp t
         | arrow s d => @interp _ base_interp s -> @interp _ base_interp d
         end.

    Fixpoint related {base_type} {base_interp : base_type -> Type} (R : forall t, relation (base_interp t)) {t : type base_type}
      : relation (interp base_interp t)
      := match t with
         | base t => R t
         | arrow s d => @related _ _ R s ==> @related _ _ R d
         end%signature.

    Notation eqv := (@related _ _ (fun _ => eq)).

    Fixpoint related_hetero {base_type} {base_interp1 base_interp2 : base_type -> Type}
             (R : forall t, base_interp1 t -> base_interp2 t -> Prop) {t : type base_type}
      : interp base_interp1 t -> interp base_interp2 t -> Prop
      := match t with
         | base t => R t
         | arrow s d => respectful_hetero _ _ _ _ (@related_hetero _ _ _ R s) (fun _ _ => @related_hetero _ _ _ R d)
         end%signature.

    Fixpoint related_hetero3 {base_type} {base_interp1 base_interp2 base_interp3 : base_type -> Type}
             (R : forall t, base_interp1 t -> base_interp2 t -> base_interp3 t -> Prop) {t : type base_type}
      : interp base_interp1 t -> interp base_interp2 t -> interp base_interp3 t -> Prop
      := match t with
         | base t => R t
         | arrow s d
           => fun f g h
              => forall x y z, @related_hetero3 _ _ _ _ R s x y z -> @related_hetero3 _ _ _ _ R d (f x) (g y) (h z)
         end.

    Fixpoint app_curried {base_type} {f : base_type -> Type} {t : type base_type}
      : interp f t -> for_each_lhs_of_arrow (interp f) t -> f (final_codomain t)
      := match t with
         | base t => fun v _ => v
         | arrow s d => fun F x_xs => @app_curried _ f d (F (fst x_xs)) (snd x_xs)
         end.

    Fixpoint app_curried_gen {base_type} {f : type base_type -> Type} (app : forall s d, f (arrow s d) -> f s -> f d)
             {t : type base_type}
      : f t -> for_each_lhs_of_arrow f t -> f (base (final_codomain t))
      := match t with
         | base t => fun v _ => v
         | arrow s d => fun F x_xs => @app_curried_gen _ f app d (app _ _ F (fst x_xs)) (snd x_xs)
         end.

    Fixpoint map_for_each_lhs_of_arrow {base_type} {f g : type base_type -> Type}
             (F : forall t, f t -> g t)
             {t}
      : for_each_lhs_of_arrow f t -> for_each_lhs_of_arrow g t
      := match t with
         | base t => fun 'tt => tt
         | arrow s d => fun '(x, xs) => (F s x, @map_for_each_lhs_of_arrow _ f g F d xs)
         end.

    Fixpoint andb_bool_for_each_lhs_of_arrow {base_type} {f g : type base_type -> Type}
             (R : forall t, f t -> g t -> bool)
             {t}
      : for_each_lhs_of_arrow f t -> for_each_lhs_of_arrow g t -> bool
      := match t with
         | base t => fun _ _ => true
         | arrow s d => fun x_xs y_ys => R s (fst x_xs) (fst y_ys) && @andb_bool_for_each_lhs_of_arrow _ f g R d (snd x_xs) (snd y_ys)
         end%bool.

    Fixpoint and_for_each_lhs_of_arrow {base_type} {f g : type base_type -> Type}
             (R : forall t, f t -> g t -> Prop)
             {t}
      : for_each_lhs_of_arrow f t -> for_each_lhs_of_arrow g t -> Prop
      := match t with
         | base t => fun _ _ => True
         | arrow s d => fun x_xs y_ys => R s (fst x_xs) (fst y_ys) /\ @and_for_each_lhs_of_arrow _ f g R d (snd x_xs) (snd y_ys)
         end.

    Definition is_base {base_type} (t : type base_type) : bool
      := match t with
         | type.base _ => true
         | type.arrow _ _ => false
         end.

    Definition is_not_higher_order {base_type} : type base_type -> bool
      := andb_each_lhs_of_arrow is_base.

    Section interpM.
      Context {base_type} (M : Type -> Type) (base_interp : base_type -> Type).
      (** half-monadic denotation function; denote [type]s into their
          interpretation in [Type]/[Set], wrapping the codomain of any
          arrow in [M]. *)
      Fixpoint interpM (t : type base_type) : Type
        := match t with
           | base t => base_interp t
           | arrow s d => @interpM s -> M (@interpM d)
           end.
      Fixpoint interpM_final' (withM : bool) (t : type base_type)
        := match t with
           | base t => if withM then M (base_interp t) else base_interp t
           | arrow s d => interpM_final' false s -> interpM_final' true d
           end.
      Definition interpM_final := interpM_final' true.

      Fixpoint interpM_return (t : type base_type) : M (base_interp (final_codomain t)) -> interpM_final t
        := match t with
           | base t => fun v => v
           | arrow s d => fun v _ => @interpM_return d v
           end.
    End interpM.

    Definition domain {base_type} (t : type base_type)
      : type base_type
      := match t with
         | arrow s d => s
         | base _ => t
         end.

    Definition codomain {base_type} (t : type base_type) : type base_type
      := match t with
         | arrow s d => d
         | t => t
         end.

    Class try_make_transport_cpsT {base : Type}
      := try_make_transport_cpsv : forall (P : base -> Type) t1 t2, ~> option (P t1 -> P t2).
    #[global] Hint Mode try_make_transport_cpsT ! : typeclass_instances.
    Global Arguments try_make_transport_cpsT : clear implicits.

    Class try_make_transport_cps_correctT {base : Type}
          {base_beq : base -> base -> bool}
          {try_make_transport_cps : @type.try_make_transport_cpsT base}
          {reflect_base_beq : reflect_rel (@eq base) base_beq}
      := try_make_transport_cps_correctP
         : forall P t1 t2,
          try_make_transport_cps P t1 t2
          = fun T k
            => k match Sumbool.sumbool_of_bool (base_beq t1 t2) with
                 | left pf => Some (rew [fun t => P t1 -> P t] (reflect_to_dec _ pf) in id)
                 | right _ => None
                 end.

    #[global] Hint Mode try_make_transport_cps_correctT ! - - - : typeclass_instances.
    Global Arguments try_make_transport_cps_correctT base {_ _ _}.

    Section transport_cps.
      Context {base_type : Type}.
      Context {try_make_transport_base_type_cps : @try_make_transport_cpsT base_type}.

      Fixpoint try_make_transport_cps (P : type base_type -> Type) (t1 t2 : type base_type)
        : ~> option (P t1 -> P t2)
        := match t1, t2 with
           | base t1, base t2 => try_make_transport_base_type_cps (fun t => P (base t)) t1 t2
           | arrow s1 d1, arrow s2 d2
             => (trs <-- try_make_transport_cps (fun s => P (arrow s _)) _ _;
                  trd <-- try_make_transport_cps (fun d => P (arrow _ d)) _ _;
                return (Some (fun v => trd (trs v))))
           | base _, _
           | arrow _ _, _
             => (return None)
           end%cps.

      Definition try_transport_cps (P : type base_type -> Type) (t1 t2 : type base_type) (v : P t1) : ~> option (P t2)
        := (tr <-- try_make_transport_cps P t1 t2;
            return (Some (tr v)))%cps.

      Definition try_transport (P : type base_type -> Type) (t1 t2 : type base_type) (v : P t1) : option (P t2)
        := try_transport_cps P t1 t2 v _ id.
    End transport_cps.

    Global Hint Extern 1 (@try_make_transport_cpsT (type ?base_type)) => notypeclasses refine (@try_make_transport_cps base_type _) : typeclass_instances. (* notypeclasses refine to avoid universe bugs in simple apply; hint instead of instance for COQBUG(https://github.com/coq/coq/issues/10072) *)

    (*
    Fixpoint try_transport {base_type}
             (try_transport_base_type : forall (P : base_type -> Type) t1 t2, P t1 -> option (P t2))
             (P : type base_type -> Type) (t1 t2 : type base_type) : P t1 -> option (P t2)
      := match t1, t2 return P t1 -> option (P t2) with
         | base t1, base t2
           => try_transport_base_type (fun t => P (base t)) t1 t2
         | arrow s d, arrow s' d'
           => fun v
             => (v <- (try_transport
                       try_transport_base_type (fun s => P (arrow s d))
                       s s' v);
                  (try_transport
                     try_transport_base_type (fun d => P (arrow s' d))
                     d d' v))%option
         | base _, _
         | arrow _ _, _
           => fun _ => None
         end.
*)
  End type.
  Notation type := type.type.
  Declare Scope etype_scope.
  Delimit Scope etype_scope with etype.
  Bind Scope etype_scope with type.type.
  Global Arguments type.base {_} _%etype.
  Infix "->" := type.arrow : etype_scope.
  Infix "==" := type.eqv : type_scope.
  Module base.
    Local Notation einterp := type.interp.
    Module type.
      Inductive type {base_type : Type} := type_base (t : base_type) | prod (A B : type) | list (A : type) | option (A : type) | unit.
      Global Arguments type : clear implicits.
      Class BaseTypeHasNatT {base : Type} := nat : base.
      Global Arguments BaseTypeHasNatT : clear implicits.
    End type.
    Notation type := type.type.

    Class BaseHasNatCorrectT {base} {base_interp : base -> Type} {baseHasNat : type.BaseTypeHasNatT base} :=
      {
        to_nat : base_interp type.nat -> nat;
        of_nat : nat -> base_interp type.nat;
        of_to_nat : forall (P : _ -> Type) x, P (of_nat (to_nat x)) -> P x;
        to_of_nat : forall (P : _ -> Type) x, P (to_nat (of_nat x)) -> P x
      }.
    Global Arguments BaseHasNatCorrectT {base} base_interp {_}.

    Definition reflect_type_beq {base} {base_beq} {r : reflect_rel (@eq base) base_beq}
      : reflect_rel (@eq (type base)) (@type.type_beq base base_beq)
      := reflect_of_beq (@type.internal_type_dec_bl _ _ (proj1 (reflect_to_beq _))) (@type.internal_type_dec_lb _ _ (proj2 (reflect_to_beq _))).
    Global Hint Extern 1 (reflect (@eq (type ?base) ?x ?y) _) => notypeclasses refine (@reflect_type_beq base _ _ x y) : typeclass_instances.

    Fixpoint interp {base} (base_interp : base -> Type) (ty : type base)
      := match ty with
         | type.type_base t => base_interp t
         | type.unit => Datatypes.unit
         | type.prod A B => interp base_interp A * interp base_interp B
         | type.list A => Datatypes.list (interp base_interp A)
         | type.option A => Datatypes.option (interp base_interp A)
         end%type.

    Fixpoint interp_beq {base base_interp} (base_interp_beq : forall b : base, base_interp b -> base_interp b -> bool) {t}
      : interp base_interp t -> interp base_interp t -> bool
      := match t with
         | type.type_base t => @base_interp_beq t
         | type.prod A B => prod_beq _ _ (@interp_beq _ _ base_interp_beq A) (@interp_beq _ _ base_interp_beq B)
         | type.list A => list_beq _ (@interp_beq _ _ base_interp_beq A)
         | type.option A => option_beq (@interp_beq _ _ base_interp_beq A)
         | type.unit => fun _ _ => true
         end.

    Lemma reflect_interp_eq {base base_interp base_interp_beq} {reflect_base_interp_eq : forall b : base, reflect_rel (@eq (base_interp b)) (base_interp_beq b)} {t}
      : reflect_rel (@eq (interp base_interp t)) (@interp_beq base base_interp base_interp_beq t).
    Proof. induction t; cbn [interp interp_beq]; eauto with typeclass_instances. Qed.
    Global Hint Extern 1 (reflect (@eq (interp ?base_interp ?t) ?x ?y) _) => notypeclasses refine (@reflect_interp_eq _ base_interp _ _ x y) : typeclass_instances.

    Fixpoint interp_beq_hetero {base base_interp} (base_interp_beq_hetero : forall b1 b2 : base, base_interp b1 -> base_interp b2 -> bool) {t1 t2}
      : interp base_interp t1 -> interp base_interp t2 -> bool
      := match t1, t2 return interp base_interp t1 -> interp base_interp t2 -> bool with
         | type.type_base t1, type.type_base t2 => @base_interp_beq_hetero t1 t2
         | type.prod A1 B1, type.prod A2 B2
           => prod_beq_hetero (@interp_beq_hetero _ _ base_interp_beq_hetero A1 A2) (@interp_beq_hetero _ _ base_interp_beq_hetero B1 B2)
         | type.list A1, type.list A2 => list_beq_hetero (@interp_beq_hetero _ _ base_interp_beq_hetero A1 A2)
         | type.option A1, type.option A2 => option_beq_hetero (@interp_beq_hetero _ _ base_interp_beq_hetero A1 A2)
         | type.unit, type.unit => fun _ _ => true
         | type.type_base _, _
         | type.prod _ _, _
         | type.list _, _
         | type.option _, _
         | type.unit, _
           => fun _ _ => false
         end.

    Lemma reflect_interp_eq_hetero_uniform {base base_interp}
          {base_interp_beq_hetero : forall t1 t2, base_interp t1 -> base_interp t2 -> bool}
          {reflect_base_interp_eq_hetero_uniform : forall b : base, reflect_rel (@eq (base_interp b)) (base_interp_beq_hetero b b)} {t}
      : reflect_rel (@eq (interp base_interp t)) (@interp_beq_hetero base base_interp base_interp_beq_hetero t t).
    Proof. induction t; cbn [interp interp_beq]; eauto with typeclass_instances. Qed.
    Global Hint Extern 1 (reflect _ (@interp_beq_hetero ?base ?base_interp ?base_interp_beq_hetero ?t ?t ?x ?y))
    => notypeclasses refine (@reflect_interp_eq base base_interp base_interp_beq_hetero _ t x y) : typeclass_instances.

    Fixpoint try_make_transport_cps
             {base}
             {try_make_transport_base_type_cps : @type.try_make_transport_cpsT base}
             (P : type base -> Type) (t1 t2 : type base)
      : ~> option (P t1 -> P t2)
      := match t1, t2 with
         | type.type_base t1, type.type_base t2
           => type.try_make_transport_cpsv (fun t => P (type.type_base t)) t1 t2
         | type.unit, type.unit
           => (return (Some (fun x => x)))
         | type.prod A B, type.prod A' B'
           => (trA <-- try_make_transport_cps (fun A => P (type.prod A _)) _ _;
                trB <-- try_make_transport_cps (fun B => P (type.prod _ B)) _ _;
              return (Some (fun v => trB (trA v))))
         | type.list A, type.list A' => try_make_transport_cps (fun A => P (type.list A)) A A'
         | type.option A, type.option A' => try_make_transport_cps (fun A => P (type.option A)) A A'
         | type.type_base _, _
         | type.prod _ _, _
         | type.list _, _
         | type.option _, _
         | type.unit, _
           => (return None)
         end%cps.

    Global Hint Extern 1 (@type.try_make_transport_cpsT (type ?base)) => notypeclasses refine (@try_make_transport_cps base _) : typeclass_instances. (* notypeclasses refine to avoid universe bugs in simple apply; hint instead of instance for COQBUG(https://github.com/coq/coq/issues/10072) *)

    Definition try_transport_cps
               {base}
               {try_make_transport_base_type_cps : @type.try_make_transport_cpsT base}
               (P : type base -> Type) (t1 t2 : type base) (v : P t1) : ~> option (P t2)
      := (tr <-- try_make_transport_cps P t1 t2;
            return (Some (tr v)))%cps.

    Definition try_transport
               {base}
               {try_make_transport_base_type_cps : @type.try_make_transport_cpsT base}
               (P : type base -> Type) (t1 t2 : type base) (v : P t1) : option (P t2)
      := try_transport_cps P t1 t2 v _ id.
  End base.
  Bind Scope etype_scope with base.type.
  Infix "*" := base.type.prod : etype_scope.
  Notation "()" := base.type.unit : etype_scope.

  Module pattern.
    Module base.
      Local Notation einterp := type.interp.
      Module type.
        Inductive type {base_type : Type} := var (p : positive) | type_base (t : base_type) | prod (A B : type) | list (A : type) | option (A : type) | unit.
        Global Arguments type : clear implicits.
      End type.
      Notation type := type.type.

      Module Notations.
        Declare Scope pbtype_scope.
        Declare Scope ptype_scope.
        Bind Scope pbtype_scope with type.type.
        Delimit Scope ptype_scope with ptype.
        Delimit Scope pbtype_scope with pbtype.
        Notation "A * B" := (type.prod A%ptype B%ptype) : ptype_scope.
        Notation "A * B" := (type.prod A%pbtype B%pbtype) : pbtype_scope.
        Notation "()" := base.type.unit : pbtype_scope.
        Notation "()" := (type.base base.type.unit) : ptype_scope.
        Notation "A -> B" := (@type.arrow (base.type _) A%ptype B%ptype) : ptype_scope.
        Notation "' n" := (type.var n) : pbtype_scope.
        Notation "' n" := (type.base (type.var n)) : ptype_scope.
        Notation "'1" := (type.var 1) : pbtype_scope.
        Notation "'2" := (type.var 2) : pbtype_scope.
        Notation "'3" := (type.var 3) : pbtype_scope.
        Notation "'4" := (type.var 4) : pbtype_scope.
        Notation "'5" := (type.var 5) : pbtype_scope.
        Notation "'1" := (type.base (type.var 1)) : ptype_scope.
        Notation "'2" := (type.base (type.var 2)) : ptype_scope.
        Notation "'3" := (type.base (type.var 3)) : ptype_scope.
        Notation "'4" := (type.base (type.var 4)) : ptype_scope.
        Notation "'5" := (type.base (type.var 5)) : ptype_scope.
      End Notations.

    Fixpoint interp {base} (base_interp : base -> Type) (lookup : positive -> Type) (ty : type base)
      := match ty with
         | type.type_base t => base_interp t
         | type.unit => Datatypes.unit
         | type.prod A B => interp base_interp lookup A * interp base_interp lookup B
         | type.list A => Datatypes.list (interp base_interp lookup A)
         | type.option A => Datatypes.option (interp base_interp lookup A)
         | type.var n => lookup n
         end%type.
    End base.
    Notation type base := (type.type (base.type base)).
    Export base.Notations.
  End pattern.
  Export pattern.base.Notations.

  Module expr.
    Section with_var.
      Context {base_type : Type}.
      Local Notation type := (type base_type).
      Context {ident : type -> Type}
              {var : type -> Type}.

      Inductive expr : type -> Type :=
      | Ident {t} (idc : ident t) : expr t
      | Var {t} (v : var t) : expr t
      | Abs {s d} (f : var s -> expr d) : expr (s -> d)
      | App {s d} (f : expr (s -> d)) (x : expr s) : expr d
      | LetIn {A B} (x : expr A) (f : var A -> expr B) : expr B
      .
    End with_var.

    Fixpoint interp {base_type ident} {interp_base_type : base_type -> Type}
             (interp_ident : forall t, ident t -> type.interp interp_base_type t)
             {t} (e : @expr base_type ident (type.interp interp_base_type) t)
      : type.interp interp_base_type t
      := match e in expr t return type.interp _ t with
         | Ident t idc => interp_ident _ idc
         | Var t v => v
         | Abs s d f => fun x : type.interp interp_base_type s
                        => @interp _ _ _ interp_ident _ (f x)
         | App s d f x => (@interp _ _ _ interp_ident _ f)
                            (@interp _ _ _ interp_ident _ x)
         | LetIn A B x f
           => dlet y := @interp _ _ _ interp_ident _ x in
               @interp _ _ _ interp_ident _ (f y)
         end.

    Section with_interp.
      Context {base_type : Type}
              {ident : type base_type -> Type}
              {interp_base_type : base_type -> Type}
              (interp_ident : forall t, ident t -> type.interp interp_base_type t).

      Fixpoint interp_related_gen
               {var : type base_type -> Type}
               (R : forall t, var t -> type.interp interp_base_type t -> Prop)
               {t} (e : @expr base_type ident var t)
        : type.interp interp_base_type t -> Prop
        := match e in expr t return type.interp interp_base_type t -> Prop with
           | expr.Var t v1 => R t v1
           | expr.App s d f x
             => fun v2
                => exists fv xv,
                    @interp_related_gen var R _ f fv
                    /\ @interp_related_gen var R _ x xv
                    /\ fv xv == v2
           | expr.Ident t idc
             => fun v2 => interp_ident _ idc == v2
           | expr.Abs s d f1
             => fun f2
                => forall x1 x2,
                    R _ x1 x2
                    -> @interp_related_gen var R d (f1 x1) (f2 x2)
           | expr.LetIn s d x f (* combine the App rule with the Abs rule *)
             => fun v2
                => exists fv xv,
                    @interp_related_gen var R _ x xv
                    /\ (forall x1 x2,
                           R _ x1 x2
                           -> @interp_related_gen var R d (f x1) (fv x2))
                    /\ fv xv == v2
           end.

      Definition interp_related {t} (e : @expr base_type ident (type.interp interp_base_type) t) : type.interp interp_base_type t -> Prop
        := @interp_related_gen (type.interp interp_base_type) (@type.eqv) t e.
    End with_interp.

    Definition Expr {base_type ident} t := forall var, @expr base_type ident var t.
    Definition APP {base_type ident s d} (f : Expr (s -> d)) (x : Expr s) : Expr d
      := fun var => @App base_type ident var s d (f var) (x var).

    Definition Interp {base_type ident interp_base_type} interp_ident {t} (e : @Expr base_type ident t)
      : type.interp interp_base_type t
      := @interp base_type ident interp_base_type interp_ident t (e _).

    (** [Interp (APP _ _)] is the same thing as Gallina application of
        the [Interp]retations of the two arguments to [APP]. *)
    Definition Interp_APP {base_type ident interp_base_type interp_ident} {s d} (f : @Expr base_type ident (s -> d)) (x : @Expr base_type ident s)
      : @Interp base_type ident interp_base_type interp_ident _ (APP f x)
        = Interp interp_ident f (Interp interp_ident x)
      := eq_refl.

    (** Same as [Interp_APP], but for any reflexive relation, not just
        [eq] *)
    Definition Interp_APP_rel_reflexive {base_type ident interp_base_type interp_ident} {s d} {R} {H:Reflexive R}
               (f : @Expr base_type ident (s -> d)) (x : @Expr base_type ident s)
      : R (@Interp base_type ident interp_base_type interp_ident _ (APP f x))
          (Interp interp_ident f (Interp interp_ident x))
      := H _.

    Module Export Notations.
      Declare Scope expr_scope.
      Declare Scope Expr_scope.
      Declare Scope expr_pat_scope.
      Delimit Scope expr_scope with expr.
      Delimit Scope Expr_scope with Expr.
      Delimit Scope expr_pat_scope with expr_pat.
      Bind Scope expr_scope with expr.
      Bind Scope Expr_scope with Expr.
      Infix "@" := App : expr_scope.
      Infix "@" := APP : Expr_scope.
      Notation "\ x .. y , f" := (Abs (fun x => .. (Abs (fun y => f%expr)) .. )) : expr_scope.
      Notation "'λ' x .. y , f" := (Abs (fun x => .. (Abs (fun y => f%expr)) .. )) : expr_scope.
      Notation "'expr_let' x := A 'in' b" := (LetIn A (fun x => b%expr)) : expr_scope.
      Notation "'$$' x" := (Var x) : expr_scope.
      Notation "### x" := (Ident x) : expr_scope.
    End Notations.
  End expr.
  Export expr.Notations.
  Notation expr := expr.expr.
  Notation Expr := expr.Expr.

  Module ident.
    Section generic.
      Context {base : Type}
              {base_interp : base -> Type}.
      Local Notation base_type := (@base.type base).
      Local Notation type := (@type.type base_type).
      Local Notation base_type_interp := (@base.interp base base_interp).
      Context {ident var : type -> Type}.
      Class BuildIdentT :=
        {
          ident_Literal : forall {t}, base_interp t -> ident (type.base (base.type.type_base t));
          ident_nil : forall {t}, ident (type.base (base.type.list t));
          ident_cons : forall {t}, ident (type.base t -> type.base (base.type.list t) -> type.base (base.type.list t));
          ident_Some : forall {t}, ident (type.base t -> type.base (base.type.option t));
          ident_None : forall {t}, ident (type.base (base.type.option t));
          ident_pair : forall {A B}, ident (type.base A -> type.base B -> type.base (A * B));
          ident_tt : ident (type.base base.type.unit)
        }.
      Context {buildIdent : BuildIdentT}.

      Section correctness_class.
        Context {ident_interp : forall t, ident t -> type.interp (base.interp base_interp) t}.

        Class BuildInterpIdentCorrectT :=
          {
            interp_ident_Literal : forall {t v}, ident_interp (type.base (base.type.type_base t)) (ident_Literal (t:=t) v) = ident.literal v;
            interp_ident_nil : forall {t}, ident_interp _ (ident_nil (t:=t)) = nil;
            interp_ident_cons : forall {t}, ident_interp _ (ident_cons (t:=t)) = cons;
            interp_ident_Some : forall {t}, ident_interp _ (ident_Some (t:=t)) = Some;
            interp_ident_None : forall {t}, ident_interp _ (ident_None (t:=t)) = None;
            interp_ident_pair : forall {A B}, ident_interp _ (ident_pair (A:=A) (B:=B)) = pair;
          }.
      End correctness_class.

      Local Notation expr := (@expr.expr base_type ident var).

      Definition reify_list {t} (ls : list (expr (type.base t))) : expr (type.base (base.type.list t))
        := Datatypes.list_rect
             (fun _ => _)
             (expr.Ident ident_nil)
             (fun x _ xs => expr.Ident ident_cons @ x @ xs)%expr
             ls.

      Definition reify_option {t} (v : option (expr (type.base t))) : expr (type.base (base.type.option t))
        := Datatypes.option_rect
             (fun _ => _)
             (fun x => expr.Ident ident_Some @ x)%expr
             (expr.Ident ident_None)
             v.

      Fixpoint smart_Literal {t:base_type} : base_type_interp t -> expr (type.base t)
        := match t with
           | base.type.type_base t => fun v => expr.Ident (ident_Literal v)
           | base.type.prod A B
             => fun '((a, b) : base_type_interp A * base_type_interp B)
                => expr.Ident ident_pair @ (@smart_Literal A a) @ (@smart_Literal B b)
           | base.type.list A
             => fun v : list (base_type_interp A)
                => reify_list (List.map (@smart_Literal A) v)
           | base.type.option A
             => fun v : option (base_type_interp A)
                => reify_option (option_map (@smart_Literal A) v)
           | base.type.unit => fun _ => expr.Ident ident_tt
           end%expr.

      Section eager_rect.
        Let type_base' (x : base) : @base.type base := base.type.type_base x.
        Let base' {bt} (x : Compilers.base.type bt) : type.type _ := type.base x.
        Local Coercion base' : base.type >-> type.type.
        Local Coercion type_base' : base >-> base.type.
        Import base.type.

        Context {ident_interp : forall t, ident t -> type.interp (base.interp base_interp) t}.
        Context {baseTypeHasNat : BaseTypeHasNatT base}.
        Local Notation nat := (match nat return base with x => x end).

        (** We define a restricted class of identifers used for eager computation *)
        Inductive restricted_ident : type.type base_type -> Type :=
        | restricted_ident_nat_rect {P:base_type} : restricted_ident ((unit -> P) -> (nat -> P -> P) -> nat -> P)
        | restricted_ident_nat_rect_arrow {P Q:base_type} : restricted_ident ((P -> Q) -> (nat -> (P -> Q) -> (P -> Q)) -> nat -> P -> Q)
        | restricted_ident_list_rect {A P:base_type} : restricted_ident ((unit -> P) -> (A -> list A -> P -> P) -> list A -> P)
        | restricted_ident_list_rect_arrow {A P Q:base_type} : restricted_ident ((P -> Q) -> (A -> list A -> (P -> Q) -> (P -> Q)) -> list A -> P -> Q)
        | restricted_ident_List_nth_default {T:base_type} : restricted_ident (T -> list T -> nat -> T)
        | restricted_ident_eager_nat_rect {P:base_type}: restricted_ident ((unit -> P) -> (nat -> P -> P) -> nat -> P)
        | restricted_ident_eager_nat_rect_arrow {P Q:base_type} : restricted_ident ((P -> Q) -> (nat -> (P -> Q) -> (P -> Q)) -> nat -> P -> Q)
        | restricted_ident_eager_list_rect {A P:base_type} : restricted_ident ((unit -> P) -> (A -> list A -> P -> P) -> list A -> P)
        | restricted_ident_eager_list_rect_arrow {A P Q:base_type} : restricted_ident ((P -> Q) -> (A -> list A -> (P -> Q) -> (P -> Q)) -> list A -> P -> Q)
        | restricted_ident_eager_List_nth_default {T:base_type} : restricted_ident (T -> list T -> nat -> T)
        .

        Class BuildEagerIdentT :=
          {
            ident_nat_rect {P:base_type} : ident ((unit -> P) -> (nat -> P -> P) -> nat -> P)
            ; ident_nat_rect_arrow {P Q:base_type} : ident ((P -> Q) -> (nat -> (P -> Q) -> (P -> Q)) -> nat -> P -> Q)
            ; ident_list_rect {A P:base_type} : ident ((unit -> P) -> (A -> list A -> P -> P) -> list A -> P)
            ; ident_list_rect_arrow {A P Q:base_type} : ident ((P -> Q) -> (A -> list A -> (P -> Q) -> (P -> Q)) -> list A -> P -> Q)
            ; ident_List_nth_default {T:base_type} : ident (T -> list T -> nat -> T)
            ; ident_eager_nat_rect {P:base_type}: ident ((unit -> P) -> (nat -> P -> P) -> nat -> P)
            ; ident_eager_nat_rect_arrow {P Q:base_type} : ident ((P -> Q) -> (nat -> (P -> Q) -> (P -> Q)) -> nat -> P -> Q)
            ; ident_eager_list_rect {A P:base_type} : ident ((unit -> P) -> (A -> list A -> P -> P) -> list A -> P)
            ; ident_eager_list_rect_arrow {A P Q:base_type} : ident ((P -> Q) -> (A -> list A -> (P -> Q) -> (P -> Q)) -> list A -> P -> Q)
            ; ident_eager_List_nth_default {T:base_type} : ident (T -> list T -> nat -> T)
          }.

        Context {buildEagerIdent : BuildEagerIdentT}.

        Section correctness_class.
          Context {baseHasNatCorrect : base.BaseHasNatCorrectT base_interp}.

          Local Notation of_nat := (@base.of_nat base base_interp _ baseHasNatCorrect).
          Local Notation to_nat := (@base.to_nat base base_interp _ baseHasNatCorrect).

          Class BuildInterpEagerIdentCorrectT :=
            {
              interp_ident_nat_rect {P:base_type}
              : ident_interp _ (@ident_nat_rect _ P)
                = (fun O_case S_case n
                   => Thunked.nat_rect (base_type_interp P) O_case (fun n => S_case (of_nat n)) (to_nat n))
                    :> ((Datatypes.unit -> _) -> (base_type_interp nat -> _ -> _) -> base_type_interp nat -> _)

              ; interp_ident_nat_rect_arrow {P Q:base_type}
                : ident_interp _ (@ident_nat_rect_arrow _ P Q)
                  = (fun O_case S_case n
                     => nat_rect_arrow_nodep O_case (fun n => S_case (of_nat n)) (to_nat n))
                      :> ((base_type_interp P -> base_type_interp Q) -> (base_type_interp nat -> (base_type_interp P -> base_type_interp Q) -> base_type_interp P -> base_type_interp Q) -> base_type_interp nat -> base_type_interp P -> base_type_interp Q)

              ; interp_ident_list_rect {A P:base_type}
                : ident_interp _ (@ident_list_rect _ A P) = Thunked.list_rect _
              ; interp_ident_list_rect_arrow {A P Q:base_type}
                : ident_interp _ (@ident_list_rect_arrow _ A P Q) = @list_rect_arrow_nodep _ (base_type_interp P) (base_type_interp Q)
              ; interp_ident_List_nth_default {T:base_type}
                : ident_interp _ (@ident_List_nth_default _ T)
                  = (fun d ls n => @List.nth_default _ d ls (to_nat n))
                      :> (base_type_interp T -> Datatypes.list (base_type_interp T) -> base_interp nat -> base_type_interp T)

              ; interp_ident_eager_nat_rect {P:base_type}
                : ident_interp _ (@ident_eager_nat_rect _ P)
                  = (fun O_case S_case n
                     => ident.eagerly Thunked.nat_rect (base_type_interp P) O_case (fun n => S_case (of_nat n)) (to_nat n))
                      :> ((Datatypes.unit -> _) -> (base_type_interp nat -> _ -> _) -> base_type_interp nat -> _)

              ; interp_ident_eager_nat_rect_arrow {P Q:base_type}
                : ident_interp _ (@ident_eager_nat_rect_arrow _ P Q)
                  = (fun O_case S_case n
                     => ident.eagerly (@nat_rect_arrow_nodep) _ _ O_case (fun n => S_case (of_nat n)) (to_nat n))
                      :> ((base_type_interp P -> base_type_interp Q) -> (base_type_interp nat -> (base_type_interp P -> base_type_interp Q) -> base_type_interp P -> base_type_interp Q) -> base_type_interp nat -> base_type_interp P -> base_type_interp Q)

              ; interp_ident_eager_list_rect {A P:base_type}
                : ident_interp _ (@ident_eager_list_rect _ A P) = ident.eagerly Thunked.list_rect _
              ; interp_ident_eager_list_rect_arrow {A P Q:base_type}
                : ident_interp _ (@ident_eager_list_rect_arrow _ A P Q) = ident.eagerly (@list_rect_arrow_nodep) _ (base_type_interp P) (base_type_interp Q)
              ; interp_ident_eager_List_nth_default {T:base_type}
                : ident_interp _ (@ident_eager_List_nth_default _ T)
                  = (fun d ls n => ident.eagerly (@List.nth_default) _ d ls (to_nat n))
                      :> (base_type_interp T -> Datatypes.list (base_type_interp T) -> base_interp nat -> base_type_interp T)
            }.
        End correctness_class.

        Definition fromRestrictedIdent {t} (idc : restricted_ident t) : ident t
          := match idc with
             | restricted_ident_nat_rect P => ident_nat_rect
             | restricted_ident_nat_rect_arrow P Q => ident_nat_rect_arrow
             | restricted_ident_list_rect A P => ident_list_rect
             | restricted_ident_list_rect_arrow A P Q => ident_list_rect_arrow
             | restricted_ident_List_nth_default T => ident_List_nth_default
             | restricted_ident_eager_nat_rect P => ident_eager_nat_rect
             | restricted_ident_eager_nat_rect_arrow P Q => ident_eager_nat_rect_arrow
             | restricted_ident_eager_list_rect A P => ident_eager_list_rect
             | restricted_ident_eager_list_rect_arrow A P Q => ident_eager_list_rect_arrow
             | restricted_ident_eager_List_nth_default T => ident_eager_List_nth_default
             end.

        Class ToRestrictedIdentT :=
          toRestrictedIdent : forall {t}, ident t -> Datatypes.option (restricted_ident t).

        Context {toRestrictedIdent : ToRestrictedIdentT}.

        (** N.B. These proofs MUST be transparent for things to compute *)
        Class ToFromRestrictedIdentT :=
          {
            transparent_toFromRestrictedIdent_eq : forall {t} (idc : restricted_ident t),
              toRestrictedIdent _ (fromRestrictedIdent idc) = Datatypes.Some idc
            ; transparent_fromToRestrictedIdent_eq : forall {t} (idc : ident t),
                option_map fromRestrictedIdent (toRestrictedIdent _ idc) = option_map (fun _ => idc) (toRestrictedIdent _ idc)
          }.

        Context {toFromRestrictedIdent : ToFromRestrictedIdentT}.

        Local Coercion fromRestrictedIdent : restricted_ident >-> ident.

        Section eager_ident_rect.
          Context (R : forall t, ident t -> Type)
                  (eager_nat_rect_f : forall P, R _ (@ident_eager_nat_rect _ P))
                  (eager_nat_rect_arrow_f : forall P Q, R _ (@ident_eager_nat_rect_arrow _ P Q))
                  (eager_list_rect_f : forall A P, R _ (@ident_eager_list_rect _ A P))
                  (eager_list_rect_arrow_f : forall A P Q, R _ (@ident_eager_list_rect_arrow _ A P Q))
                  (eager_List_nth_default_f : forall T, R _ (@ident_eager_List_nth_default _ T))
                  {t} (idc : ident t).

          Definition eager_ident_rect
            : Datatypes.option (R t idc)
            := ((match toRestrictedIdent _ idc as idc'
                       return match option_map (fun _ => idc) idc' with
                              | Some idc' => Datatypes.option (R t idc')
                              | None => Datatypes.option (R t idc)
                              end -> Datatypes.option (R t idc)
                 with
                 | Some _ => fun v => v
                 | None => fun v => v
                 end)
                  (rew [fun idc' => match idc' with
                                    | Datatypes.Some idc' => Datatypes.option (R _ idc')
                                    | Datatypes.None => Datatypes.option (R _ idc)
                                    end]
                       transparent_fromToRestrictedIdent_eq idc in
                      match toRestrictedIdent _ idc as idc'
                            return match option_map fromRestrictedIdent idc' with
                                   | Some idc' => Datatypes.option (R t idc')
                                   | None => Datatypes.option (R t idc)
                                   end
                      with
                      | Datatypes.None => Datatypes.None
                      | Datatypes.Some idc'
                        => match idc' return Datatypes.option (R _ idc') with
                           | restricted_ident_nat_rect _
                           | restricted_ident_nat_rect_arrow _ _
                           | restricted_ident_list_rect _ _
                           | restricted_ident_list_rect_arrow _ _ _
                           | restricted_ident_List_nth_default _
                             => Datatypes.None
                           | restricted_ident_eager_nat_rect P => Datatypes.Some (eager_nat_rect_f P)
                           | restricted_ident_eager_nat_rect_arrow P Q => Datatypes.Some (eager_nat_rect_arrow_f P Q)
                           | restricted_ident_eager_list_rect A P => Datatypes.Some (eager_list_rect_f A P)
                           | restricted_ident_eager_list_rect_arrow A P Q => Datatypes.Some (eager_list_rect_arrow_f A P Q)
                           | restricted_ident_eager_List_nth_default T => Datatypes.Some (eager_List_nth_default_f T)
                           end
                      end)).
        End eager_ident_rect.
      End eager_rect.
    End generic.
    Global Arguments BuildIdentT {base base_interp} ident, {base} base_interp ident.
    Global Arguments ToRestrictedIdentT {_} ident {_}.
    Global Arguments BuildEagerIdentT {_} ident {_}.
    Global Arguments BuildInterpEagerIdentCorrectT {_ _ _} ident_interp {_ _ _}.
    Global Arguments ToFromRestrictedIdentT {_} ident {_ _ _}.
    Global Arguments BuildInterpIdentCorrectT {_ _ _ _} _.

    (** TODO: Do these tactics belong here or in another file? *)
    Ltac rewrite_interp_eager ident_interp :=
      let buildInterpEagerIdentCorrect := constr:(_ : ident.BuildInterpEagerIdentCorrectT ident_interp) in
      (* in case the user passed in [_] or something *)
      let ident_interp := lazymatch type of buildInterpEagerIdentCorrect with ident.BuildInterpEagerIdentCorrectT ?ident_interp => ident_interp end in
      repeat match goal with
             | [ |- context[ident_interp _ ident.ident_eager_nat_rect] ]
               => rewrite (@ident.interp_ident_eager_nat_rect _ _ _ _ _ _ _ buildInterpEagerIdentCorrect)
             | [ |- context[ident_interp _ ident.ident_eager_nat_rect_arrow] ]
               => rewrite (@ident.interp_ident_eager_nat_rect_arrow _ _ _ _ _ _ _ buildInterpEagerIdentCorrect)
             | [ |- context[ident_interp _ ident.ident_eager_list_rect] ]
               => rewrite (@ident.interp_ident_eager_list_rect _ _ _ _ _ _ _ buildInterpEagerIdentCorrect)
             | [ |- context[ident_interp _ ident.ident_eager_list_rect_arrow] ]
               => rewrite (@ident.interp_ident_eager_list_rect_arrow _ _ _ _ _ _ _ buildInterpEagerIdentCorrect)
             | [ |- context[ident_interp _ ident.ident_eager_List_nth_default] ]
               => rewrite (@ident.interp_ident_eager_List_nth_default _ _ _ _ _ _ _ buildInterpEagerIdentCorrect)
             | [ |- context[ident_interp _ ident.ident_nat_rect] ]
               => rewrite (@ident.interp_ident_nat_rect _ _ _ _ _ _ _ buildInterpEagerIdentCorrect)
             | [ |- context[ident_interp _ ident.ident_nat_rect_arrow] ]
               => rewrite (@ident.interp_ident_nat_rect_arrow _ _ _ _ _ _ _ buildInterpEagerIdentCorrect)
             | [ |- context[ident_interp _ ident.ident_list_rect] ]
               => rewrite (@ident.interp_ident_list_rect _ _ _ _ _ _ _ buildInterpEagerIdentCorrect)
             | [ |- context[ident_interp _ ident.ident_list_rect_arrow] ]
               => rewrite (@ident.interp_ident_list_rect_arrow _ _ _ _ _ _ _ buildInterpEagerIdentCorrect)
             | [ |- context[ident_interp _ ident.ident_List_nth_default] ]
               => rewrite (@ident.interp_ident_List_nth_default _ _ _ _ _ _ _ buildInterpEagerIdentCorrect)

             | [ H : context[ident_interp _ ident.ident_eager_nat_rect] |- _ ]
               => rewrite (@ident.interp_ident_eager_nat_rect _ _ _ _ _ _ _ buildInterpEagerIdentCorrect) in H
             | [ H : context[ident_interp _ ident.ident_eager_nat_rect_arrow] |- _ ]
               => rewrite (@ident.interp_ident_eager_nat_rect_arrow _ _ _ _ _ _ _ buildInterpEagerIdentCorrect) in H
             | [ H : context[ident_interp _ ident.ident_eager_list_rect] |- _ ]
               => rewrite (@ident.interp_ident_eager_list_rect _ _ _ _ _ _ _ buildInterpEagerIdentCorrect) in H
             | [ H : context[ident_interp _ ident.ident_eager_list_rect_arrow] |- _ ]
               => rewrite (@ident.interp_ident_eager_list_rect_arrow _ _ _ _ _ _ _ buildInterpEagerIdentCorrect) in H
             | [ H : context[ident_interp _ ident.ident_eager_List_nth_default] |- _ ]
               => rewrite (@ident.interp_ident_eager_List_nth_default _ _ _ _ _ _ _ buildInterpEagerIdentCorrect) in H
             | [ H : context[ident_interp _ ident.ident_nat_rect] |- _ ]
               => rewrite (@ident.interp_ident_nat_rect _ _ _ _ _ _ _ buildInterpEagerIdentCorrect) in H
             | [ H : context[ident_interp _ ident.ident_nat_rect_arrow] |- _ ]
               => rewrite (@ident.interp_ident_nat_rect_arrow _ _ _ _ _ _ _ buildInterpEagerIdentCorrect) in H
             | [ H : context[ident_interp _ ident.ident_list_rect] |- _ ]
               => rewrite (@ident.interp_ident_list_rect _ _ _ _ _ _ _ buildInterpEagerIdentCorrect) in H
             | [ H : context[ident_interp _ ident.ident_list_rect_arrow] |- _ ]
               => rewrite (@ident.interp_ident_list_rect_arrow _ _ _ _ _ _ _ buildInterpEagerIdentCorrect) in H
             | [ H : context[ident_interp _ ident.ident_List_nth_default] |- _ ]
               => rewrite (@ident.interp_ident_List_nth_default _ _ _ _ _ _ _ buildInterpEagerIdentCorrect) in H
             end.
    Ltac rewrite_interp ident_interp :=
      let buildInterpIdentCorrect := constr:(_ : ident.BuildInterpIdentCorrectT ident_interp) in
      (* in case the user passed in [_] or something *)
      let ident_interp := lazymatch type of buildInterpIdentCorrect with ident.BuildInterpIdentCorrectT ?ident_interp => ident_interp end in
      repeat match goal with
             | [ |- context[ident_interp _ (ident.ident_Literal _)] ]
               => rewrite (@ident.interp_ident_Literal _ _ _ _ _ buildInterpIdentCorrect)
             | [ |- context[ident_interp _ ident.ident_nil] ]
               => rewrite (@ident.interp_ident_nil _ _ _ _ _ buildInterpIdentCorrect)
             | [ |- context[ident_interp _ ident.ident_cons] ]
               => rewrite (@ident.interp_ident_cons _ _ _ _ _ buildInterpIdentCorrect)
             | [ |- context[ident_interp _ ident.ident_Some] ]
               => rewrite (@ident.interp_ident_Some _ _ _ _ _ buildInterpIdentCorrect)
             | [ |- context[ident_interp _ ident.ident_None] ]
               => rewrite (@ident.interp_ident_None _ _ _ _ _ buildInterpIdentCorrect)
             | [ |- context[ident_interp _ ident.ident_pair] ]
               => rewrite (@ident.interp_ident_pair _ _ _ _ _ buildInterpIdentCorrect)

             | [ H : context[ident_interp _ (ident.ident_Literal _)] |- _ ]
               => rewrite (@ident.interp_ident_Literal _ _ _ _ _ buildInterpIdentCorrect) in H
             | [ H : context[ident_interp _ ident.ident_nil] |- _ ]
               => rewrite (@ident.interp_ident_nil _ _ _ _ _ buildInterpIdentCorrect) in H
             | [ H : context[ident_interp _ ident.ident_cons] |- _ ]
               => rewrite (@ident.interp_ident_cons _ _ _ _ _ buildInterpIdentCorrect) in H
             | [ H : context[ident_interp _ ident.ident_Some] |- _ ]
               => rewrite (@ident.interp_ident_Some _ _ _ _ _ buildInterpIdentCorrect) in H
             | [ H : context[ident_interp _ ident.ident_None] |- _ ]
               => rewrite (@ident.interp_ident_None _ _ _ _ _ buildInterpIdentCorrect) in H
             | [ H : context[ident_interp _ ident.ident_pair] |- _ ]
               => rewrite (@ident.interp_ident_pair _ _ _ _ _ buildInterpIdentCorrect) in H
             end.

    Module Export Notations.
      Declare Scope ident_scope.
      Delimit Scope ident_scope with ident.
      Global Arguments expr.Ident {base_type%type ident%function var%function t%etype} idc%ident.
      Notation "# x" := (expr.Ident x) (only parsing) : expr_pat_scope.
      Notation "# x" := (@expr.Ident _ _ _ _ x) : expr_scope.
      Notation "x @ y" := (expr.App x%expr_pat y%expr_pat) (only parsing) : expr_pat_scope.

      Notation "( x , y , .. , z )" := (expr.App (expr.App (#ident_pair) .. (expr.App (expr.App (#ident_pair) x%expr) y%expr) .. ) z%expr) : expr_scope.
      Notation "x :: y" := (#ident_cons @ x @ y)%expr : expr_scope.
      Notation "[ ]" := (#ident_nil)%expr : expr_scope.
      Notation "[ x ]" := (x :: [])%expr : expr_scope.
      Notation "[ x ; y ; .. ; z ]" := (#ident_cons @ x @ (#ident_cons @ y @ .. (#ident_cons @ z @ #ident_nil) ..))%expr : expr_scope.
    End Notations.
  End ident.
  Export ident.Notations.

  Global Strategy -1000 [expr.Interp expr.interp type.interp base.interp].

  Module Import invert_expr.
    Section with_var_gen.
      Context {base_type} {ident var : type base_type -> Type}.
      Local Notation expr := (@expr base_type ident var).
      Local Notation if_arrow f t
        := (match t return Type with
            | type.arrow s d => f s d
            | type.base _ => unit
            end) (only parsing).
      Definition invert_Ident {t} (e : expr t)
        : option (ident t)
        := match e with
           | expr.Ident t idc => Some idc
           | _ => None
           end.
      Definition invert_App_cps {t P Q} (e : expr t)
                 (F1 : forall s d, expr (s -> d) -> P s d)
                 (F2 : forall t, expr t -> Q t)
        : option { s : _ & P s t * Q s }%type
        := match e with
           | expr.App A B f x => Some (existT _ A (F1 _ _ f, F2 _ x))
           | _ => None
           end.
      Definition invert_App {t} (e : expr t)
        : option { s : _ & expr (s -> t) * expr s }%type
        := invert_App_cps e (fun _ _ x => x) (fun _ x => x).
      Definition invert_Abs {s d} (e : expr (s -> d))
        : option (var s -> expr d)%type
        := match e in expr.expr t return option (if_arrow (fun s d => var s -> expr d) t) with
           | expr.Abs s d f => Some f
           | _ => None
           end.
      Definition invert_LetIn {t} (e : expr t)
        : option { s : _ & expr s * (var s -> expr t) }%type
        := match e with
           | expr.LetIn A B x f => Some (existT _ A (x, f))
           | _ => None
           end.
      Definition invert_App2_cps {t P Q R} (e : expr t)
                 (F1 : forall s d, expr (s -> d) -> P s d)
                 (F2 : forall t, expr t -> Q t)
                 (F3 : forall t, expr t -> R t)
        : option { ss' : _ & P (fst ss') (snd ss' -> t)%etype * Q (fst ss') * R (snd ss') }%type
        := (v1 <- invert_App_cps e (fun _ _ f => invert_App_cps f F1 F2) F3;
           let '(existT s (v2, r)) := v1 in
           v2 <- v2;
           let '(existT s' (p, q)) := v2 in
           Some (existT _ (s', s) (p, q, r)))%option.
      Definition invert_App2 {t} (e : expr t)
        : option { ss' : _ & expr (fst ss' -> snd ss' -> t) * expr (fst ss') * expr (snd ss') }%type
        := invert_App2_cps e (fun _ _ x => x) (fun _ x => x) (fun _ x => x).
      Definition invert_AppIdent_cps {t P} (e : expr t)
                 (F : forall t, expr t -> P t)
        : option { s : _ & ident (s -> t) * P s }%type
        := (e <- invert_App_cps e (fun _ _ f => f) F;
           let '(existT s (f, x)) := e in
           f' <- invert_Ident f;
           Some (existT _ s (f', x)))%option.
      Definition invert_AppIdent {t} (e : expr t)
        : option { s : _ & ident (s -> t) * expr s }%type
        := invert_AppIdent_cps e (fun _ x => x).
      Definition invert_AppIdent2_cps {t Q R} (e : expr t)
                 (F1 : forall t, expr t -> Q t)
                 (F2 : forall t, expr t -> R t)
        : option { ss' : _ & ident (fst ss' -> snd ss' -> t) * Q (fst ss') * R (snd ss') }%type
        := (e <- invert_App2_cps e (fun _ _ x => x) F1 F2;
           let '(existT ss' (f, x, x')) := e in
           f' <- invert_Ident f;
           Some (existT _ ss' (f', x, x')))%option.
      Definition invert_AppIdent2 {t} (e : expr t)
        : option { ss' : _ & ident (fst ss' -> snd ss' -> t) * expr (fst ss') * expr (snd ss') }%type
        := invert_AppIdent2_cps e (fun _ x => x) (fun _ x => x).
      Definition invert_Var {t} (e : expr t)
        : option (var t)
        := match e with
           | expr.Var t v => Some v
           | _ => None
           end.

      Fixpoint App_curried {t} : expr t -> type.for_each_lhs_of_arrow expr t -> expr (type.base (type.final_codomain t))
        := match t with
           | type.base t => fun e _ => e
           | type.arrow s d => fun e x => @App_curried d (e @ (fst x)) (snd x)
           end.
      Fixpoint smart_App_curried {t} (e : expr t) : type.for_each_lhs_of_arrow var t -> expr (type.base (type.final_codomain t))
        := match e in expr.expr t return type.for_each_lhs_of_arrow var t -> expr (type.base (type.final_codomain t)) with
           | expr.Abs s d f
             => fun v => @smart_App_curried d (f (fst v)) (snd v)
           | e
             => fun v => @App_curried _ e (type.map_for_each_lhs_of_arrow (fun _ v => expr.Var v) v)
           end.
      Fixpoint invert_App_curried {t} (e : expr t)
        : type.for_each_lhs_of_arrow expr t -> { t' : _ & expr t' * type.for_each_lhs_of_arrow expr t' }%type
        := match e in expr.expr t return type.for_each_lhs_of_arrow expr t -> { t' : _ & expr t' * type.for_each_lhs_of_arrow expr t' }%type with
           | expr.App s d f x
             => fun args
                => @invert_App_curried _ f (x, args)
           | e => fun args => existT _ _ (e, args)
           end.
      Definition invert_AppIdent_curried {t} (e : expr t)
        : option { t' : _ & ident t' * type.for_each_lhs_of_arrow expr t' }%type
        := match t return expr t -> _ with
           | type.base _ => fun e => let 'existT t (f, args) := invert_App_curried e tt in
                                     (idc <- invert_Ident f;
                                        Some (existT _ t (idc, args)))%option
           | _ => fun _ => None
           end e.
    End with_var_gen.

    Section with_container.
      Context {base : Type}
              {base_interp : base -> Type}
              {try_make_transport_base_type_cps : @type.try_make_transport_cpsT base}.
      Local Notation base_type := (@base.type base).
      Local Notation type := (@type.type base_type).
      Context {ident var : type -> Type}.
      Class InvertIdentT :=
        {
          invert_ident_Literal : forall {t}, ident t -> option (type.interp (base.interp base_interp) t);
          is_nil : forall {t}, ident t -> bool;
          is_cons : forall {t}, ident t -> bool;
          is_Some : forall {t}, ident t -> bool;
          is_None : forall {t}, ident t -> bool;
          is_pair : forall {t}, ident t -> bool;
          is_tt : forall {t}, ident t -> bool
        }.
      Context {invertIdent : InvertIdentT}.

      Section correctness_class.
        Context {buildIdent : ident.BuildIdentT base_interp ident}.

        Class BuildInvertIdentCorrectT :=
          {
            invert_ident_Literal_correct
            : forall {t idc v},
              invert_ident_Literal (t:=t) idc = Some v
              <-> match t return ident t -> type.interp (base.interp base_interp) t -> Prop with
                  | type.base (base.type.type_base t)
                    => fun idc v => idc = ident.ident_Literal (t:=t) v
                  | _ => fun _ _ => False
                  end idc v;
            is_nil_correct
            : forall {t idc},
                is_nil (t:=t) idc = true
                <-> match t return ident t -> Prop with
                    | type.base (base.type.list t)
                      => fun idc => idc = ident.ident_nil (t:=t)
                    | _ => fun _ => False
                    end idc;
            is_cons_correct
            : forall {t idc},
                is_cons (t:=t) idc = true
                <-> match t return ident t -> Prop with
                    | type.base t -> type.base (base.type.list _) -> type.base (base.type.list _)
                      => fun idc => existT _ _ idc = existT _ _ (ident.ident_cons (t:=t)) :> sigT ident
                    | _ => fun _ => False
                    end%etype idc;
            is_Some_correct
            : forall {t idc},
                is_Some (t:=t) idc = true
                <-> match t return ident t -> Prop with
                    | type.base t -> type.base (base.type.option _)
                      => fun idc => existT _ _ idc = existT _ _ (ident.ident_Some (t:=t)) :> sigT ident
                    | _ => fun _ => False
                    end%etype idc;
            is_None_correct
            : forall {t idc},
                is_None (t:=t) idc = true
                <-> match t return ident t -> Prop with
                    | type.base (base.type.option t)
                      => fun idc => idc = ident.ident_None (t:=t)
                    | _ => fun _ => False
                    end idc;
            is_pair_correct
            : forall {t idc},
                is_pair (t:=t) idc = true
                <-> match t return ident t -> Prop with
                    | type.base A -> type.base B -> type.base (base.type.prod _ _)
                      => fun idc => existT _ _ idc = existT _ _ (ident.ident_pair (A:=A) (B:=B)) :> sigT ident
                    | _ => fun _ => False
                    end%etype idc;
            is_tt_correct
            : forall {t idc},
                is_tt (t:=t) idc = true
                <-> match t return ident t -> Prop with
                    | type.base base.type.unit
                      => fun idc => idc = ident.ident_tt
                    | _ => fun _ => False
                    end%etype idc;
          }.
      End correctness_class.

      Local Notation expr := (@expr.expr base_type ident var).
      Local Notation try_transportP P := (@type.try_transport _ _ P _ _).
      Local Notation try_transport := (try_transportP _).
      Let type_base (x : base) : @base.type base := base.type.type_base x.
      Let base' {bt} (x : Compilers.base.type bt) : type.type _ := type.base x.
      Local Coercion base' : base.type >-> type.type.
      Local Coercion type_base : base >-> base.type.

      Fixpoint reflect_list_cps' {t} (e : expr t)
        : ~> option (list (expr (type.base match t return base_type with
                                           | type.base (base.type.list t) => t
                                           | _ => base.type.unit
                                           end)))
        := match e in expr.expr t
                 return ~> option (list (expr (type.base match t return base_type with
                                                         | type.base (base.type.list t) => t
                                                         | _ => base.type.unit
                                                         end)))
           with
           | #maybe_nil => if is_nil maybe_nil then (return (Some nil)) else (return None)
           | #maybe_cons @ x @ xs
             => if is_cons maybe_cons
                then (x' <-- type.try_transport_cps expr _ _ x;
                        xs' <-- @reflect_list_cps' _ xs;
                        xs' <-- type.try_transport_cps (fun t => list (expr (type.base match t return base_type with
                                                                                                                                                 | type.base (base.type.list t) => t
                                                                                                                                                 | _ => base.type.unit
                                                                                                                                                 end))) _ _ xs';
                      return (Some (x' :: xs')%list))
                else (return None)
           | _ => (return None)
           end%expr_pat%expr%cps.

      Definition reflect_list_cps {t} (e : expr (type.base (base.type.list t)))
        : ~> option (list (expr (type.base t)))
        := reflect_list_cps' e.
      Global Arguments reflect_list_cps {t} e [T] k.

      Definition reflect_list {t} (e : expr (type.base (base.type.list t)))
        : option (list (expr (type.base t)))
        := reflect_list_cps e id.

      Definition invert_pair_cps {t P Q} (e : expr t)
                 (F1 : forall t, expr t -> P t)
                 (F2 : forall t, expr t -> Q t)
                 (A := match t with type.base (base.type.prod A B) => A | _ => t end)
                 (B := match t with type.base (base.type.prod A B) => B | _ => t end)
        : option (P A * Q B)
        := (v <- invert_AppIdent2_cps e F1 F2;
           let '(existT _ (maybe_pair, a, b)) := v in
           if is_pair maybe_pair
           then a <- try_transport a; b <- try_transport b; Some (a, b)%core
           else None)%option.
      Definition invert_pair {A B} (e : expr (A * B))
        : option (expr A * expr B)
        := invert_pair_cps e (fun _ x => x) (fun _ x => x).
      Definition invert_Literal {t} (e : expr t)
        : option (type.interp (base.interp base_interp) t)
        := match e with
           | expr.Ident _ idc => invert_ident_Literal idc
           | _ => None
           end%expr_pat%expr.
      Definition invert_nil {t} (e : expr (base.type.list t)) : bool
        := match invert_Ident e with
           | Some maybe_nil => is_nil maybe_nil
           | _ => false
           end.
      Definition invert_None {t} (e : expr (base.type.option t)) : bool
        := match invert_Ident e with
           | Some maybe_None => is_None maybe_None
           | _ => false
           end.
      Definition invert_Some {t} (e : expr (base.type.option t))
        : option (expr t)
        := match e with
           | #maybe_Some @ v
             => if is_Some maybe_Some
                then try_transport v
                else None
           | _ => None
           end%expr_pat.
      Definition invert_tt (e : expr base.type.unit) : bool
        := match invert_Ident e with
           | Some maybe_tt => is_tt maybe_tt
           | _ => false
           end.

      Definition reflect_option {t} (e : expr (base.type.option t))
        : option (option (expr t))
        := match invert_None e, invert_Some e with
           | true, _ => Some None
           | _, Some x => Some (Some x)
           | false, None => None
           end.

      Definition invert_cons_cps {t P Q} (e : expr t)
                 (F1 : forall t, expr t -> P t)
                 (F2 : forall t, expr t -> Q t)
                 (A := match t with type.base (base.type.list A) => A | _ => base.type.unit end)
        : option (P A * Q (base.type.list A))
        := (v <- invert_AppIdent2_cps e F1 F2;
           let '(existT _ (maybe_cons, a, b)) := v in
           if is_cons maybe_cons
           then a <- try_transport a; b <- try_transport b; Some (a, b)%core
           else None)%option.

      Definition invert_cons {t} (e : expr (base.type.list t))
        : option (expr t * expr (base.type.list t))
        := invert_cons_cps e (fun _ x => x) (fun _ x => x).

      Fixpoint reflect_smart_Literal {t : base_type} : expr t -> option (base.interp base_interp t)
        := match t with
           | base.type.type_base t => invert_Literal
           | base.type.prod A B
             => fun e => ab <- invert_pair e;
                           a <- @reflect_smart_Literal A (fst ab);
                           b <- @reflect_smart_Literal B (snd ab);
                           Some (a, b)
           | base.type.list A
             => fun e => e <- reflect_list e;
                           Option.List.lift (List.map (@reflect_smart_Literal A) e)
           | base.type.option A
             => fun e => e <- reflect_option e;
                           match e with
                           | Some e => option_map (@Some _) (@reflect_smart_Literal A e)
                           | None => Some None
                           end
           | base.type.unit => fun e => if invert_tt e then Some tt else None
           end%option.
    End with_container.
    Global Arguments invert_ident_Literal {_ _ _ _} {t} _, {_ _ _ _} t _.
    Global Arguments is_nil {_ _ _ _} {t} _, {_ _ _ _} t _.
    Global Arguments is_cons {_ _ _ _} {t} _, {_ _ _ _} t _.
    Global Arguments is_None {_ _ _ _} {t} _, {_ _ _ _} t _.
    Global Arguments is_Some {_ _ _ _} {t} _, {_ _ _ _} t _.
    Global Arguments is_pair {_ _ _ _} {t} _, {_ _ _ _} t _.
    Global Arguments is_tt {_ _ _ _} {t} _, {_ _ _ _} t _.
    Global Arguments InvertIdentT {base base_interp} ident, {base} base_interp ident.
  End invert_expr.

  Module DefaultValue.
    (** This module provides "default" inhabitants for the
        interpretation of PHOAS types and for the PHOAS [expr] type.
        These values are used for things like [nth_default] and in
        other places where we need to provide a dummy value in cases
        that will never actually be reached in correctly used code. *)
    Module type.
      Module base.
        Class DefaultT {base : Type} {base_interp : base -> Type}
          := defaultv : forall {t}, base_interp t.
        Global Hint Mode DefaultT ! - : typeclass_instances.

        Section with_base.
          Context {base : Type}
                  {base_interp : base -> Type}.
          Local Notation base_type := (@base.type base).
          Local Notation type := (@type.type base_type).
          Local Notation base_type_interp := (@base.interp base base_interp).
          Context {baseDefault : @DefaultT base base_interp}.

          Fixpoint default {t : base.type base} : base_type_interp t
            := match t with
               | base.type.type_base t => defaultv (t:=t)
               | base.type.unit => tt
               | base.type.list _ => nil
               | base.type.prod A B
                 => (@default A, @default B)
               | base.type.option A => None
               end.
        End with_base.
        Global Hint Extern 1 (@DefaultT (base.type ?base) (@base.interp ?base ?base_interp)) => notypeclasses refine (@default base base_interp _) : typeclass_instances. (* notypeclasses refine to avoid universe bugs in simple apply; hint instead of instance for COQBUG(https://github.com/coq/coq/issues/10072) *)
      End base.

      Section with_base.
        Context {base_type : Type}
                {base_interp : base_type -> Type}.
        Local Notation type := (@type.type base_type).
        Context {baseDefault : @base.DefaultT base_type base_interp}.

        Fixpoint default {t} : type.interp base_interp t
          := match t with
             | type.base x => base.defaultv (t:=x)
             | type.arrow s d => fun _ => @default d
             end.
      End with_base.
    End type.

    Module expr.
      Module base.
        Section generic.
          Context {base : Type}
                  {base_interp : base -> Type}.
          Context {baseDefault : @type.base.DefaultT base base_interp}.
          Local Notation base_type := (@base.type base).
          Local Notation type := (@type.type base_type).
          Local Notation base_type_interp := (@base.interp base base_interp).
          Local Notation base_type_default := (@type.base.default base base_interp baseDefault).
          Context {ident : type -> Type}.
          Context {buildIdent : @ident.BuildIdentT base base_interp ident}.

          Section with_var.
            Context {var : type -> Type}.
            Local Notation expr := (@expr.expr base_type ident var).

            Definition default {t : base_type} : expr (type.base t)
              := ident.smart_Literal (@base_type_default t).
          End with_var.

          Definition Default {t : base_type} : expr.Expr (type.base t) := fun _ => default.
        End generic.
      End base.

      Section generic.
        Context {base : Type}
                {base_interp : base -> Type}.
        Context {baseDefault : @type.base.DefaultT base base_interp}.
        Local Notation base_type := (@base.type base).
        Local Notation type := (@type.type base_type).
        Local Notation base_type_interp := (@base.interp base base_interp).
        Local Notation base_type_default := (@type.base.default base base_interp baseDefault).
        Context {ident : type -> Type}.
        Context {buildIdent : @ident.BuildIdentT base base_interp ident}.

        Section with_var.
          Context {var : type -> Type}.
          Local Notation expr := (@expr.expr base_type ident var).

          Fixpoint default {t : type} : @expr t
            := match t with
               | type.base x => base.default
               | type.arrow s d => λ _, @default d
               end%expr.
        End with_var.

        Definition Default {t} : expr.Expr t := fun _ => default.
      End generic.
      Global Hint Extern 1 (@type.base.DefaultT (type.type (base.type ?base)) (@expr.expr (base.type ?base) ?ident ?var))
      => notypeclasses refine (@default base _ _ ident _ var) : typeclass_instances.
      Global Hint Extern 1 (@type.base.DefaultT (type.type (base.type ?base)) (@expr.Expr (base.type ?base) ?ident))
      => notypeclasses refine (@Default base _ _ ident _) : typeclass_instances.
    End expr.
  End DefaultValue.

  Notation reify_list := ident.reify_list.
  Notation reify_option := ident.reify_option.

  Module GallinaReify.
    Module base.
      Notation reify := ident.smart_Literal.

      Section generic.
        Context {base : Type}
                {base_interp : base -> Type}.
        Local Notation base_type := (@base.type base).
        Local Notation type := (@type.type base_type).
        Local Notation base_type_interp := (@base.interp base base_interp).
        Context {ident : type -> Type}.
        Context {buildIdent : @ident.BuildIdentT base base_interp ident}.

        Definition Reify_as (t : base_type) (v : base_type_interp t) : expr.Expr (type.base t)
          := fun var => reify v.
      End generic.

      (*(** [Reify] does Ltac type inference to get the type *)
      Notation Reify v
        := (Reify_as (base.reify_type_of v) (fun _ => v)) (only parsing).*)
    End base.

    Section generic.
      Context {base : Type}
              {base_interp : base -> Type}.
      Local Notation base_type := (@base.type base).
      Local Notation type := (@type.type base_type).
      Local Notation base_type_interp := (@base.interp base base_interp).
      Context {ident : type -> Type}.
      Context {buildIdent : @ident.BuildIdentT base base_interp ident}.

      Section value.
        Context (var : type -> Type).
        Fixpoint value (t : type)
          := match t return Type with
             | type.arrow s d => var s -> value d
             | type.base t => base_type_interp t
             end%type.
      End value.

      Section reify.
        Context {var : type -> Type}.
        Local Notation expr := (@expr.expr base_type ident var).

        Fixpoint reify {t : type} {struct t}
          : value var t -> expr t
          := match t return value var t -> expr t with
             | type.arrow s d
               => fun (f : var s -> value var d)
                  => (λ x , @reify d (f x))%expr
             | type.base t
               => base.reify
             end.
      End reify.

      Fixpoint reify_as_interp {t : type} {struct t}
        : type.interp base_type_interp t -> @expr _ ident (type.interp base_type_interp) t
        := match t return type.interp base_type_interp t -> expr t with
           | type.arrow s d
             => fun (f : type.interp base_type_interp s -> type.interp base_type_interp d)
                => (λ x , @reify_as_interp d (f x))%expr
           | type.base t
             => base.reify
           end.

      Definition Reify_as (t : type) (v : forall var, value var t) : expr.Expr t
        := fun var => reify (v _).

      (*
    (** [Reify] does Ltac type inference to get the type *)
    Notation Reify v
      := (Reify_as (reify_type_of v) (fun _ => v)) (only parsing).*)
    End generic.
  End GallinaReify.

  Module GeneralizeVar.
    (** In both lazy and cbv evaluation strategies, reduction under
        lambdas is only done at the very end.  This means that if we
        have a computation which returns a PHOAS syntax tree, and we
        plug in two different values for [var], the computation is run
        twice.  This module provides a way of computing a
        representation of terms which does not suffer from this issue.
        By computing a flat representation, and then going back to
        PHOAS, the cbv strategy will fully compute the preceeding
        PHOAS passes only once, and the lazy strategy will share
        computation among the various uses of [var] (because there are
        no lambdas to get blocked on) and thus will also compute the
        preceeding PHOAS passes only once. *)
    Module Flat.
      Section with_base.
        Context {base_type : Type}
                {ident : type base_type -> Type}.
        Local Notation type := (@type.type base_type).

        Inductive expr : type -> Type :=
        | Ident {t} (idc : ident t) : expr t
        | Var (t : type) (n : positive) : expr t
        | Abs (s : type) (n : positive) {d} (f : expr d) : expr (s -> d)
        | App {s d} (f : expr (s -> d)) (x : expr s) : expr d
        | LetIn {A B} (n : positive) (ex : expr A) (eC : expr B) : expr B.
      End with_base.
    End Flat.

    Definition ERROR {T} (v : T) : T. exact v. Qed.

    Section with_base.
      Context {base_type : Type}
              {base_type_interp : base_type -> Type}.
      Local Notation type := (@type.type base_type).
      Context {ident : type -> Type}.
      Context {try_make_transport_base_type_cps : @type.try_make_transport_cpsT base_type}
              {exprDefault : forall var, @DefaultValue.type.base.DefaultT type (@expr base_type ident var)}.
      Local Notation expr := (@expr base_type ident).

      Fixpoint to_flat' {t} (e : @expr (fun _ => PositiveMap.key) t)
               (cur_idx : PositiveMap.key)
        : Flat.expr t
        := match e in expr.expr t return Flat.expr t with
           | expr.Var t v => Flat.Var t v
           | expr.App s d f x => Flat.App
                                   (@to_flat' _ f cur_idx)
                                   (@to_flat' _ x cur_idx)
           | expr.Ident t idc => Flat.Ident idc
           | expr.Abs s d f
             => Flat.Abs s cur_idx
                         (@to_flat'
                            d (f cur_idx)
                            (Pos.succ cur_idx))
           | expr.LetIn A B ex eC
             => Flat.LetIn
                  cur_idx
                  (@to_flat' A ex cur_idx)
                  (@to_flat'
                     B (eC cur_idx)
                     (Pos.succ cur_idx))
           end.

      Fixpoint from_flat {t} (e : Flat.expr t)
        : forall var, PositiveMap.t { t : type & var t } -> @expr var t
        := match e in Flat.expr t return forall var, _ -> expr t with
           | Flat.Var t v
             => fun var ctx
                => match (tv <- PositiveMap.find v ctx;
                            type.try_transport var _ _ (projT2 tv))%option with
                   | Some v => expr.Var v
                   | None => ERROR DefaultValue.type.base.defaultv
                   end
           | Flat.Ident t idc => fun var ctx => expr.Ident idc
           | Flat.App s d f x
             => let f' := @from_flat _ f in
                let x' := @from_flat _ x in
                fun var ctx => expr.App (f' var ctx) (x' var ctx)
           | Flat.Abs s cur_idx d f
             => let f' := @from_flat d f in
                fun var ctx
                => expr.Abs (fun v => f' var (PositiveMap.add cur_idx (existT _ s v) ctx))
           | Flat.LetIn A B cur_idx ex eC
             => let ex' := @from_flat A ex in
                let eC' := @from_flat B eC in
                fun var ctx
                => expr.LetIn
                     (ex' var ctx)
                     (fun v => eC' var (PositiveMap.add cur_idx (existT _ A v) ctx))
           end.

      Definition to_flat {t} (e : expr t) : Flat.expr t
        := to_flat' e 1%positive.
      Definition ToFlat {t} (E : Expr t) : Flat.expr t
        := to_flat (E _).
      Definition FromFlat {t} (e : Flat.expr t) : Expr t
        := let e' := @from_flat t e in
           fun var => e' var (PositiveMap.empty _).
      Definition GeneralizeVar {t} (e : @expr (fun _ => PositiveMap.key) t) : Expr t
        := FromFlat (to_flat e).
    End with_base.
  End GeneralizeVar.

  Module Classes.
    Class ExprInfoT :=
      {
        base : Type;
        ident : type (base.type base) -> Type;
        base_interp : base -> Type;
        ident_interp : forall t, ident t -> type.interp (base.interp base_interp) t
      }.

    Class ExprExtraInfoT {exprInfo : ExprInfoT} :=
      {
        base_beq : base -> base -> bool;
        base_interp_beq : forall {t1 t2}, base_interp t1 -> base_interp t2 -> bool;
        try_make_transport_base_cps : type.try_make_transport_cpsT base;
        baseHasNat : base.type.BaseTypeHasNatT base;
        buildIdent : ident.BuildIdentT base_interp ident;
        toRestrictedIdent : ident.ToRestrictedIdentT ident;
        buildEagerIdent : ident.BuildEagerIdentT ident;
        invertIdent : InvertIdentT base_interp ident;
        defaultBase : @DefaultValue.type.base.DefaultT base base_interp;
        reflect_base_beq : reflect_rel (@eq base) base_beq;
        reflect_base_interp_beq : forall {t}, reflect_rel (@eq (base_interp t)) (@base_interp_beq t t);
        try_make_transport_base_cps_correct : type.try_make_transport_cps_correctT base;
        baseHasNatCorrect : base.BaseHasNatCorrectT base_interp;
        toFromRestrictedIdent : ident.ToFromRestrictedIdentT ident;
        buildInvertIdentCorrect : BuildInvertIdentCorrectT;
        buildInterpIdentCorrect : ident.BuildInterpIdentCorrectT ident_interp;
        buildInterpEagerIdentCorrect : ident.BuildInterpEagerIdentCorrectT ident_interp;
        ident_interp_Proper : forall t, Proper (eq ==> type.eqv) (ident_interp t)
      }.
    #[global]
     Existing Instances
     try_make_transport_base_cps
     baseHasNat
     buildIdent
     toRestrictedIdent
     buildEagerIdent
     invertIdent
     defaultBase
     reflect_base_beq
     reflect_base_interp_beq
     try_make_transport_base_cps_correct
     baseHasNatCorrect
     toFromRestrictedIdent
     buildInvertIdentCorrect
     buildInterpIdentCorrect
     buildInterpEagerIdentCorrect
     ident_interp_Proper.
  End Classes.
End Compilers.
