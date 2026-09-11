# @freddy03h/lenses-ppx

Maintained fork of the unmaintained [Astrocoders/lenses-ppx](https://github.com/Astrocoders/lenses-ppx), updated for **ReScript 12 only** (uncurried by default). No compatibility with older compilers.

Generates GADT field lenses for record types — useful when you need to compose lenses into lists/arrays (e.g. [reschema](https://github.com/rescriptbr/reschema)).

## Install

```sh
npm install --save-dev @freddy03h/lenses-ppx
```

Add to `rescript.json`:

```json
{
  "ppx-flags": ["@freddy03h/lenses-ppx/ppx"]
}
```

## Usage

```rescript
module StateLenses = %lenses(
  type state = {
    email: string,
    age: int,
    hobbies: array<string>,
  }
)
```

Expands to roughly:

```rescript
module StateLenses = {
  type state = {
    email: string,
    age: int,
    hobbies: array<string>,
  }
  type rec field<_> =
    | Email: field<string>
    | Age: field<int>
    | Hobbies: field<array<string>>
    | HobbiesAt(int): field<option<string>>
    | HobbiesAtExn(int): field<string>
  let get: type value. (state, field<value>) => value = (state, field) =>
    switch field {
    | Email => state.email
    | Age => state.age
    | Hobbies => state.hobbies
    | HobbiesAt(index) => state.hobbies->Array.get(index)
    | HobbiesAtExn(index) => state.hobbies->Array.get(index)->Option.getOrThrow
    }
  let set: type value. (state, field<value>, value) => state = (state, field, value) =>
    switch field {
    | Email => {...state, email: value}
    | Age => {...state, age: value}
    | Hobbies => {...state, hobbies: value}
    | HobbiesAt(index) =>
      switch value {
      | Some(item) => {...state, hobbies: state.hobbies->Array.with(index, item)}
      | None => state
      }
    | HobbiesAtExn(index) => {...state, hobbies: state.hobbies->Array.with(index, value)}
    }
}
```

Array fields also get `*At` (safe, `option`) and `*AtExn` (throws if the index is out of range). `set` copies the array (`Array.with`) instead of mutating it.

```rescript
open StateLenses

let state = {email: "user@example.com", age: 969, hobbies: ["foo", "bar"]}

Console.log(state->get(Email))
Console.log(state->get(Age))
Console.log(state->get(HobbiesAt(1))) // Some("bar")
Console.log(state->get(HobbiesAtExn(0))) // "foo"
```

Attribute form (generates `bartux_get` / `bartux_set`):

```rescript
@lenses
type bartux = {
  color: string,
  top: int,
}

let bartux = {color: "red", top: 10}

Console.log(bartux->bartux_get(Color))
Console.log(bartux->bartux_set(Top, 20))
```

## Develop

npm workspaces monorepo: `packages/ppx`, `packages/demo`.

```sh
npm install
```

Build the PPX (requires [opam](https://opam.ocaml.org/) and OCaml 4.14.2):

```sh
cd packages/ppx
opam switch create . 4.14.2 --deps-only -y
eval $(opam env)
dune build
```

Build the demo from the repo root:

```sh
npm run build
```

## Alternatives

- https://github.com/scoville/re-optic/blob/master/docs/lenses-ppx.md — stricter, closer to optics standards
