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
