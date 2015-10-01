# Assignment:
number:::number   = 42
opposite:::boolean = true

# Conditions:
number = -42 if opposite

# Functions:
#square:::(x:number)->number = (x) -> x * x

# Arrays:
list:::number = [1, 2, 3, 4, 5]

# Objects:
math =
  root:   Math.sqrt
  square: square
  cube:   (x) -> x * square x

# Splats:
#race = (winner :::string, runners... :::string[]) ->
#  console.log winner, runners

# Existence:
alert "I knew it!" if elvis?

# Array comprehensions:
cubes = (math.cube num for num in list)


#square = (x:::number) -> x * x
#cube   = (x) -> square(x) * x

fill = (container, liquid = "coffee") ->
  "Filling the #{container} with #{liquid}..."


song = ["do", "re", "mi", "fa", "so"]

singers = {Jagger: "Rock", Elvis: "Roll"}

bitlist = [
  1, 0, 1
  0, 0, 1
  1, 1, 0
]

kids =
  brother:
    name: "Max"
    age:  11
  sister:
    name: "Ida"
    age:  9

$('.account').attr class: 'active'

log object.class


outer = 1
changeNumbers = ->
  inner = -1
  outer = 10
inner = changeNumbers()


mood = greatlyImproved if singing

if happy and knowsIt
  clapsHands()
  chaChaCha()
else
  showIt()

date = if friday then sue else jill
