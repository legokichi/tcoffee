// Assignment:
var number:number   = 42;
var opposite:boolean = true;

// Conditions:
if (opposite){
  number = -42
}

// Functions:
var square:(x:number)=>number = (x) => x * x

// Arrays:
var list:number[] = [1, 2, 3, 4, 5]

// Objects:
var math ={
  root:   Math.sqrt,
  square: square,
  cube:   (x) => x * square(x)
}

// Splats:
var race = (winner:string, ...runners:string[]) =>
  console.log(winner, runners)

// Existence:
if(elvis !== null && typeof elvis !== "undefined"){
  alert("I knew it!")
}

// Array comprehensions:
var cubes = (()=>{
	for(let num in list){
		Math.pow(num,2);
	}
})();


var square = (x:number) => x * x;
var cube   = (x) => square(x) * x;

var fill = function(container, liquid = "coffee"){
  return `Filling the ${container} with ${liquid}...`;
}


var song = ["do", "re", "mi", "fa", "so"];

var singers = {Jagger: "Rock", Elvis: "Roll"};

var bitlist = [
  1, 0, 1,
  0, 0, 1,
  1, 1, 0
];

var kids ={
  brother:{
    name: "Max",
    age:  11
  },
  sister:{
    name: "Ida",
    age:  9
  }
}

$('.account').attr({
  "class": 'active'
});

log(object["class"]);



var outer = 1
changeNumbers = ->
  var inner = -1
  var outer = 10
var inner = changeNumbers()



var mood = greatlyImproved if singing

if happy and knowsIt
  clapsHands()
  chaChaCha()
else
  showIt()

date = if friday then sue else jill
