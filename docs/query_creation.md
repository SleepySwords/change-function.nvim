# Writing queries for different languages

`change-function.nvim` uses treesitter to find the location of argument and
function parameters in order to swap them. By default, `change-function.nvim`
uses the `textobjects.scm` queries as a way to find the parameters. However,
sometimes these queries are not suitable, as they do not contain the function
name captures (we might use the highlights.scm to remedy this in the future),
but also incorrectly match arguments. Writing queries to match the argument is
fortunately quite simple.

The queries used are specified in the config for each filetype, typically they
are named `function_params.scm` files and are individual to each language. These
files are stored in the runtime `queries` directory, so local configurations are
also able to add or override them.

## 1. Finding the function calls/declarations

You can use the `:InspectTree` command to see how treesitter parses the
language. The items we want to find are the all the function declarations and
function calls. This can be done by having the cursor over a function
call/declaration and seeing where it lands on the tree.

Usually, they would have a similar name to `function_item` or `call_expression`.

<img width="921" alt="Untitled" src="https://github.com/user-attachments/assets/5dcf0e73-64d7-41f9-99ea-a5d21f6d2559">

## 2. Matching the function arguments/parameters

We want to capture the individual arguments from the query so their ranges can
be found and swapped. Usually, these arguments are within the
`arguments`/`parameters` field of the function declaration or call expression.
To capture the individual arguments we want to append a capture called
`parameter.inner` (ie: `@parameter.inner`), to the end of the query. As some
parsers may use the expressions themselves (like: `binary_expression`), a
placeholder value `(_)` could be used.

Ensure, you place both a function declaration and a call expression if your
language supports it to update references across your project.

## 3. Matching the function/method names

You may also would want to add captures for identifiers, such as `method_name`
and `function_name`. This allows for `change-function.nvim` to detect if the
cursor is currently on top of a method/function name.


The process is similar to matching functions arguments/parameters, but instead
looking and matching for a node that is similar to `identifier`, this can be
found by looking at the highlighted node when your cursor is on top of a
function/call name.


Currently, there is no difference between how `method_name` and `function_name`
are handle, but they may be handled differently in the future.

## 4. Matching for argument insertion.

The `@parameter.initial_insertion` capture must be added if you want to insert
an argument into a function that contains no arguments.

This is as a result of the other captures not being suitable in finding out
where the arguments are supposed to go if there are not parameters.

This uses the start range of the capture to find where to place the arguments.

## Match from the root of function declaration/argument
**NOTE:** When matching function arguments or function names, match them from
the root of the function declaration/call, as shown below, as to be able to 
match the identifier as well as the argument.

## Putting this together for Rust
```query
; Match function declarations
(function_item
  name: (identifier) @function_name
  parameters: (parameters
    (parameter)? @parameter.inner
    ")" @parameter.initial_insertion
  )
) @function.outer

(function_signature_item
  name: (identifier) @function_name
  parameters: (parameters
    (parameter) @parameter.inner
    ")" @parameter.initial_insertion
  )
) @function.outer

; Match function call
(call_expression
  arguments: (arguments
    (_)? @parameter.inner
    ")" @parameter.initial_insertion
  )
) @call.outer

(call_expression
  function: (field_expression
    field: (field_identifier) @method_name
  )
) @call.outer

(call_expression
  function: (scoped_identifier
    name: (identifier) @function_name
  )
) @call.outer

(call_expression
  function: (identifier) @function_name
) @call.outer
```

If you have written a nice query, please contribute it here :)

