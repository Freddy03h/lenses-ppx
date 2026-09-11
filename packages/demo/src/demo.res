module StateLenses = %lenses(
  type state = {
    email: string,
    age: int,
    hobbies: array<string>,
  }
)

open StateLenses

let state = {
  email: "user@example.com",
  age: 0,
  hobbies: ["foo", "bar"],
}

Console.log(state->get(Email))
Console.log(state->get(Age))
Console.log(state->get(Hobbies))
Console.log(state->get(HobbiesAt(1)))
Console.log(state->get(HobbiesAtExn(0)))
Console.log(state->set(HobbiesAt(0), Some("baz")))
Console.log(state->set(HobbiesAt(1), None))
Console.log(state->set(HobbiesAtExn(1), "qux"))

@lenses
type bartux = {
  color: string,
  top: int,
  tags: array<string>,
}

let bartux = {color: "red", top: 10, tags: ["a", "b"]}

Console.log(bartux->bartux_get(Color))
Console.log(bartux->bartux_set(Top, 20))
Console.log(bartux->bartux_get(TagsAt(1)))
Console.log(bartux->bartux_set(TagsAtExn(0), "z"))
