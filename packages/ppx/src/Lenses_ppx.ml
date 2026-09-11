open Ppxlib
open Asttypes
open Parsetree
open Ast_helper
open Utils

let loc = Location.none

let constructor_name field = String.capitalize_ascii field.pld_name.txt

let array_element_type field =
  match field.pld_type.ptyp_desc with
  | Ptyp_constr ({ txt = Lident "array"; _ }, [ inner ]) -> Some inner
  | _ -> None

let field_lid field = { loc; txt = Lident field.pld_name.txt }
let field_access field = Exp.field [%expr values] (field_lid field)

let ctor_pat name args = Pat.construct { loc; txt = Lident name } args
let index_pat () = Some (Pat.var { loc; txt = "index" })

let record_with_field ~fields field value_expr =
  Exp.record
    [ (field_lid field, value_expr) ]
    (* Spread not needed with a single field — avoids "redundant with" *)
    (if List.length fields > 1 then Some [%expr values] else None)

(* Immutable update: Array.with(array, index, item) *)
let array_with_expr array_expr item_expr =
  expr_apply
    (Exp.ident { loc; txt = Ldot (Lident "Array", "with") })
    [ array_expr; [%expr index]; item_expr ]

let gadt_constr ~gadt_field_name ~name ~args payload =
  Type.constructor ~loc:Location.none ~args
    ~res:
      (Typ.constr ~loc:Location.none
         { txt = Lident gadt_field_name; loc = Location.none }
         [ payload ])
    { txt = name; loc = Location.none }

let gadt_constructors_for_field ~gadt_field_name field =
  let name = constructor_name field in
  let whole =
    gadt_constr ~gadt_field_name ~name ~args:(Pcstr_tuple []) field.pld_type
  in
  match array_element_type field with
  | None -> [ whole ]
  | Some inner ->
    [
      whole;
      gadt_constr ~gadt_field_name ~name:(name ^ "At")
        ~args:(Pcstr_tuple [ [%type: int] ])
        [%type: [%t inner] option];
      gadt_constr ~gadt_field_name ~name:(name ^ "AtExn")
        ~args:(Pcstr_tuple [ [%type: int] ])
        inner;
    ]

let get_cases_for_field field =
  let name = constructor_name field in
  let access = field_access field in
  let whole = Exp.case (ctor_pat name None) access in
  match array_element_type field with
  | None -> [ whole ]
  | Some _ ->
    [
      whole;
      Exp.case
        (ctor_pat (name ^ "At") (index_pat ()))
        (expr_apply [%expr Array.get] [ access; [%expr index] ]);
      Exp.case
        (ctor_pat (name ^ "AtExn") (index_pat ()))
        (expr_apply [%expr Option.getOrThrow]
           [ expr_apply [%expr Array.get] [ access; [%expr index] ] ]);
    ]

let set_cases_for_field ~fields field =
  let name = constructor_name field in
  let whole =
    Exp.case (ctor_pat name None) (record_with_field ~fields field [%expr value])
  in
  match array_element_type field with
  | None -> [ whole ]
  | Some _ ->
    [
      whole;
      Exp.case
        (ctor_pat (name ^ "At") (index_pat ()))
        [%expr
          match value with
          | Some item ->
            [%e
              record_with_field ~fields field
                (array_with_expr (field_access field) [%expr item])]
          | None -> values];
      Exp.case
        (ctor_pat (name ^ "AtExn") (index_pat ()))
        (record_with_field ~fields field
           (array_with_expr (field_access field) [%expr value]));
    ]

let create_set_lens ~type_name ~gadt_field_name ?(prefix = "") ~fields () =
  let cases = List.concat_map (set_cases_for_field ~fields) fields in
  let record_type =
    Typ.mk (Ptyp_constr ({ txt = Lident type_name; loc }, []))
  in
  let gadt_type_poly =
    Typ.mk (Ptyp_constr ({ txt = Lident gadt_field_name; loc }, [ [%type: 'value] ]))
  in
  let gadt_type_local =
    Typ.mk (Ptyp_constr ({ txt = Lident gadt_field_name; loc }, [ [%type: value] ]))
  in
  let arrow_poly =
    [%type:
      [%t record_type] -> [%t gadt_type_poly] -> 'value -> [%t record_type]]
  in
  let type_definition =
    Typ.poly [ { txt = "value"; loc } ] (ctyp_arrow ~arity:3 arrow_poly)
    |> Typ.force_poly
  in
  let type_definition_local =
    ctyp_arrow ~arity:3
      [%type:
        [%t record_type] -> [%t gadt_type_local] -> value -> [%t record_type]]
  in
  let pat_match =
    Exp.mk (Pexp_match (Exp.mk (Pexp_ident { txt = Lident "field"; loc }), cases))
  in
  (* Locally abstract type encoding for polymorphic GADT functions:
     https://caml.inria.fr/pub/docs/manual-ocaml/locallyabstract.html *)
  let body =
    expr_func ~arity:3 [%expr fun values field value -> [%e pat_match]]
  in
  let fn_name = Pat.var { txt = prefix ^ "set"; loc } in
  let pat = Pat.constraint_ fn_name type_definition in
  let body = Exp.constraint_ body type_definition_local in
  [%stri let [%p pat] = fun (type value) -> [%e body]]

let create_get_lens ~type_name ~gadt_field_name ?(prefix = "") ~fields () =
  let cases = List.concat_map get_cases_for_field fields in
  let record_type =
    Typ.mk (Ptyp_constr ({ txt = Lident type_name; loc }, []))
  in
  let gadt_type_poly =
    Typ.mk (Ptyp_constr ({ txt = Lident gadt_field_name; loc }, [ [%type: 'value] ]))
  in
  let gadt_type_local =
    Typ.mk (Ptyp_constr ({ txt = Lident gadt_field_name; loc }, [ [%type: value] ]))
  in
  let arrow_poly =
    [%type: [%t record_type] -> [%t gadt_type_poly] -> 'value]
  in
  let type_definition =
    Typ.poly [ { txt = "value"; loc } ] (ctyp_arrow ~arity:2 arrow_poly)
    |> Typ.force_poly
  in
  let type_definition_local =
    ctyp_arrow ~arity:2
      [%type: [%t record_type] -> [%t gadt_type_local] -> value]
  in
  let pat_match =
    Exp.mk (Pexp_match (Exp.mk (Pexp_ident { txt = Lident "field"; loc }), cases))
  in
  let body = expr_func ~arity:2 [%expr fun values field -> [%e pat_match]] in
  let fn_name = Pat.var { txt = prefix ^ "get"; loc } in
  let pat = Pat.constraint_ fn_name type_definition in
  let body = Exp.constraint_ body type_definition_local in
  [%stri let [%p pat] = fun (type value) -> [%e body]]

let create_gadt ~gadt_field_name ~fields =
  let constructors =
    List.concat_map (gadt_constructors_for_field ~gadt_field_name) fields
  in
  Str.type_ Recursive
    [
      Type.mk ~loc:Location.none
        ~params:[ ([%type: _], (NoVariance, NoInjectivity)) ]
        ~kind:(Ptype_variant constructors)
        { txt = gadt_field_name; loc = Location.none };
    ]

let create_structure_lenses ~type_name ~gadt_field_name ?prefix ~fields () =
  [
    create_gadt ~gadt_field_name ~fields;
    create_get_lens ~type_name ~gadt_field_name ?prefix ~fields ();
    create_set_lens ~type_name ~gadt_field_name ?prefix ~fields ();
  ]

let create_module ~type_def ~type_name ~fields =
  Mod.mk
    (Pmod_structure
       (type_def
       :: create_structure_lenses ~type_name ~gadt_field_name:"field" ~fields ()))

module Structure_mapper = struct
  let map_type_decl decl =
    let {
      ptype_attributes;
      ptype_name = { txt = type_name; _ };
      ptype_manifest;
      ptype_loc;
      ptype_kind;
      _;
    } =
      decl
    in
    match get_settings_from_attributes ptype_attributes with
    | Ok (Some { lenses = true }) -> (
      match (ptype_manifest, ptype_kind) with
      | None, Ptype_abstract ->
        fail ptype_loc "Can't generate lenses for unspecified type"
      | None, Ptype_record fields ->
        create_structure_lenses ~type_name
          ~gadt_field_name:(type_name ^ "_" ^ "field")
          ~prefix:(type_name ^ "_") ~fields ()
      | _ -> fail ptype_loc "This type is not handled by lenses-ppx")
    | Ok (Some { lenses = false }) | Ok None -> []
    | Error s -> fail ptype_loc s

  let map_structure_item mapper ({ pstr_desc; _ } as structure_item) =
    match pstr_desc with
    | Pstr_type (_rec_flag, decls) ->
      let value_bindings = decls |> List.map map_type_decl |> List.concat in
      mapper#structure_item structure_item
      :: (if List.length value_bindings > 0 then value_bindings else [])
    | _ -> [ mapper#structure_item structure_item ]

  let map_structure mapper structure =
    structure |> List.map (map_structure_item mapper) |> List.concat
end

class lenses_mapper =
  object (self)
    inherit Ast_traverse.map as super

    method! structure structure = Structure_mapper.map_structure self structure

    method! module_expr expr =
      match expr with
      | {
       pmod_desc =
         Pmod_extension
           ( { txt = "lenses"; _ },
             PStr
               [
                 {
                   pstr_desc =
                     Pstr_type
                       ( rec_flag,
                         [
                           {
                             ptype_name = { txt = type_name; _ };
                             ptype_kind = Ptype_record fields;
                             _;
                           };
                         ] );
                   _;
                 };
               ] );
       _;
      } ->
        create_module
          ~type_def:
            (Str.type_ rec_flag
               [ Type.mk ~kind:(Ptype_record fields) { txt = type_name; loc } ])
          ~type_name ~fields
      | _ -> super#module_expr expr
  end

let structure_mapper s = (new lenses_mapper)#structure s

let () =
  Driver.register_transformation ~preprocess_impl:structure_mapper "lenses-ppx"
