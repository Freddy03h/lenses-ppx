open Ppxlib
open Parsetree
open Ast_helper

let annotation_name = "lenses"
let loc = !default_loc

let fail loc message = Location.raise_errorf ~loc "%s" message

let mknoloc txt = { Location.txt; loc = Location.none }

let get_attribute_by_name attributes name =
  let filtered =
    attributes
    |> List.filter (fun { attr_name = { Location.txt; _ }; _ } -> txt = name)
  in
  match filtered with
  | [] -> Ok None
  | [ attribute ] -> Ok (Some attribute)
  | _ -> Error ("Too many occurrences of \"" ^ name ^ "\" attribute")

type generator_settings = { lenses : bool }

let get_settings_from_attributes attributes =
  match get_attribute_by_name attributes annotation_name with
  | Ok (Some _) -> Ok (Some { lenses = true })
  | Ok None -> Ok None
  | Error _ as e -> e

(** Wrap an arrow expression as a ReScript uncurried [Function$] value. *)
let expr_func ?(loc = Location.none) ~arity e =
  let attr_arity =
    Attr.mk
      { txt = "res.arity"; loc }
      (PStr [ Str.eval (Exp.constant (Const.int arity)) ])
  in
  Exp.construct ~attrs:[ attr_arity ] { txt = Lident "Function$"; loc } (Some e)

(** Mark an application as ReScript uncurried. *)
let expr_apply ?(loc = Location.none) fn args =
  let attr_uapp = Attr.mk { txt = "res.uapp"; loc } (PStr []) in
  Exp.apply ~loc ~attrs:[ attr_uapp ] fn
    (List.map (fun arg -> (Nolabel, arg)) args)

(** Wrap an arrow type as a ReScript uncurried [function$] type. *)
let ctyp_arrow ?(loc = Location.none) ~arity ctyp =
  let arity_tag = "Has_arity" ^ string_of_int arity in
  Typ.constr ~loc
    (mknoloc (Lident "function$"))
    [ ctyp; Typ.variant [ Rf.tag (mknoloc arity_tag) true [] ] Closed None ]
