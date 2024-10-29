(function_declarator
  declarator: (identifier) @function_name
  parameters: (parameter_list
    (_) @parameter.inner
  )
)
(function_declarator
  declarator: (field_identifier)  @function_name
  parameters: (parameter_list
  (_) @parameter.inner
  )
)

(call_expression
  function: (identifier) @function_name
  arguments: (argument_list
    (_) @parameter.inner
  )
)

(call_expression
  function: (field_expression
    field: (field_identifier) @function_name
  )
  arguments: (argument_list
    (_) @parameter.inner
  )
)


(init_declarator
declarator: (identifier) @function_name
value: (argument_list
(_) @parameter.inner
))

(new_expression
  type: (type_identifier) @function_name
  arguments: (argument_list
    (_) @parameter.inner
  )
)

(function_declarator
  declarator: (qualified_identifier
    name: (_) @function_name
  )
  parameters: (parameter_list
    (_) @parameter.inner
  )
)
