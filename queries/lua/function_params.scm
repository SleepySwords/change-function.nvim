(function_call
  (arguments
    (_)? @parameter.inner
    ")" @parameter.initial_insertion
  )
) @call.outer

(function_call
  name: (identifier) @function_name
)

(function_call
  name: (_
    field: (identifier) @function_name
  )
)

(function_declaration
  parameters: (parameters
    (_)? @parameter.inner
    ")" @parameter.initial_insertion
  )
) @function.outer

(function_declaration
  name: (identifier) @function_name
)

(function_declaration
  name: (_
    field: (identifier) @function_name
  )
)
