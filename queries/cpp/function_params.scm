(function_declarator
  declarator: (identifier) @function_name
  parameters: (parameter_list
    "(" @function_name
    (_)? @parameter.inner
    ")" @parameter.initial_insertion
  )
) @function.outer

(function_declarator
  declarator: (field_identifier)  @function_name
  parameters: (parameter_list
    "(" @function_name
    (_)? @parameter.inner
    ")" @parameter.initial_insertion
  )
) @function.outer

(call_expression
  function: (identifier) @function_name
  arguments: (argument_list
    "(" @function_name
    (_)? @parameter.inner
    ")" @parameter.initial_insertion
  )
) @call.outer

(call_expression
  function: (field_expression
    field: (field_identifier) @function_name
  )
  arguments: (argument_list
    "(" @function_name
    (_)? @parameter.inner
    ")" @parameter.initial_insertion
  )
) @call.outer


(init_declarator
  declarator: (identifier) @function_name
  value: (argument_list
    "(" @function_name
    (_)? @parameter.inner
    ")" @parameter.initial_insertion
  )
) @call.outer

(new_expression
  type: (type_identifier) @function_name
  arguments: (argument_list
    "(" @function_name
    (_)? @parameter.inner
    ")" @parameter.initial_insertion
  )
) @call.outer

(function_declarator
  declarator: (qualified_identifier
    name: (_) @function_name
  )
  parameters: (parameter_list
    (_)? @parameter.inner
    ")" @parameter.initial_insertion
  )
) @function.outer
