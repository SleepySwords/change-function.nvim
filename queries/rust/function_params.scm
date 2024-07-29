(function_item
    name: (identifier) @function_name
    parameters: (parameters
        (parameter) @parameter.inner
    )
)

(function_signature_item
    parameters: (parameters
        (parameter) @parameter.inner
    )
)

(call_expression
  function: (field_expression
    field: (field_identifier) @method_name
  )
  arguments: (arguments
      (_) @parameter.inner
  )
)

(call_expression
  function: (scoped_identifier
    name: (identifier) @function_name
  )
  arguments: (arguments
      (_) @parameter.inner
  )
)

(call_expression
  function: (identifier) @function_name
  arguments: (arguments
      (_) @parameter.inner
  )
)
