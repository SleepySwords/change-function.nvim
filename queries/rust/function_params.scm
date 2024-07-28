(function_item
    name: (identifier) @function
    parameters: (parameters
        (parameter) @parameter.inner
    )
)

(function_signature_item
    parameters: (parameters
        (parameter) @parameter.inner
    )
)

; (call_expression
;   (field_expression) @method)

(call_expression
  function: (field_expression
    field: (field_identifier) @method
  )
  arguments: (arguments
      (_) @parameter.inner
  )
)

(call_expression
  function: (scoped_identifier
    name: (identifier) @function
  )
  arguments: (arguments
      (_) @parameter.inner
  )
)

(call_expression
  function: (identifier) @function
  arguments: (arguments
      (_) @parameter.inner
  )
)
