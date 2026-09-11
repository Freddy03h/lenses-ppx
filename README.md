# lenses-ppx

ReScript PPX that generates GADT field lenses for record types. Useful when you need to compose lenses into lists/arrays (e.g. [reschema](https://github.com/rescriptbr/reschema)).

Compatible with **ReScript 12+** (uncurried by default).

## Install

```sh
npm install --save-dev lenses-ppx@latest
# or
yarn add lenses-ppx@latest -D
```

Add to `rescript.json`:

```json
{
  "ppx-flags": ["lenses-ppx/ppx"]
}
```

## Usage

```rescript
module StateLenses = %lenses(
  type state = {
    email: string,
    age: int,
  }
)
```

Expands to roughly:

```rescript
module StateLenses = {
  type state = {
    email: string,
    age: int,
  }
  type rec field<_> =
    | Email: field<string>
    | Age: field<int>
  let get: type value. (state, field<value>) => value = (state, field) =>
    switch field {
    | Email => state.email
    | Age => state.age
    }
  let set: type value. (state, field<value>, value) => state = (state, field, value) =>
    switch field {
    | Email => {...state, email: value}
    | Age => {...state, age: value}
    }
}
```

```rescript
open StateLenses

let state = {email: "fakenickels@gov.br", age: 969}

Console.log(state->get(Email))
Console.log(state->get(Age))
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

## Develop the PPX

Requires [opam](https://opam.ocaml.org/) and OCaml 4.14.2:

```sh
cd packages/ppx
opam switch create . 4.14.2 --deps-only -y
eval $(opam env)
dune build
```

Then build the demo:

```sh
cd packages/demo
npm install
npm run build
```

## Alternatives

- https://github.com/scoville/re-optic/blob/master/docs/lenses-ppx.md — stricter, closer to optics standards

## Background

[GADTs: A primer](https://sketch.sh/s/yH0MJiujNSiofDWOU85loX/)
