module StateLenses = %lenses(
  type state = {
    email: string,
    age: int,
  }
)

open StateLenses

let state = {email: "user@example.com", age: 0}

Console.log(state->get(Email))
Console.log(state->get(Age))

@lenses
type bartux = {
  color: string,
  top: int,
}

let bartux = {color: "red", top: 10}

Console.log(bartux->bartux_get(Color))
Console.log(bartux->bartux_set(Top, 20))
