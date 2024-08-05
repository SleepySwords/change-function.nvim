(function_call
  name: (identifier) @function_name
  (arguments
    (_) @parameter.inner
  )
)

(function_call
  name: (_
    field: (identifier) @function_name
  )
  (arguments
    (_) @parameter.inner
  )
)

(function_declaration
  name: (identifier) @function_name
  parameters: (parameters
      (_) @parameter.inner
    )
  )

(function_declaration
  name: (_
    field: (identifier) @function_name
  )
  parameters: (parameters
      (_) @parameter.inner
    )
  )
