(function_call
  name: (identifier) @function_name
  (arguments
    (_)? @parameter.inner
    ")" @insert_first_arg
  )
) @method.outer

(function_call
  name: (_
    field: (identifier) @function_name
  )
  (arguments
    (_)? @parameter.inner
    ")" @insert_first_arg
  )
) @method.outer

(function_declaration
  name: (identifier) @function_name
  parameters: (parameters
      (_)? @parameter.inner
      ")" @insert_first_arg
    )
  ) @function.outer

; Investigate why * does not work.
(function_declaration
  name: (_
    field: (identifier) @function_name
  )
  parameters: (parameters
      (_)? @parameter.inner
      ")" @insert_first_arg
    )
  ) @function.outer
