(call_expression
    arguments: (arguments
        (_) @parameter.inner
    )
)

(function_item
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
  (field_expression) @method)

(call_expression
  (scoped_identifier) @function)

(call_expression
  (identifier) @function)
