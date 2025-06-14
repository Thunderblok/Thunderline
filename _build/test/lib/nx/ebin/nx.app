{application,nx,
             [{modules,['Elixir.Inspect.Nx.Batch',
                        'Elixir.Inspect.Nx.Defn.TemplateDiff',
                        'Elixir.Inspect.Nx.Defn.Token',
                        'Elixir.Inspect.Nx.Heatmap',
                        'Elixir.Inspect.Nx.Tensor','Elixir.Nx',
                        'Elixir.Nx.Application','Elixir.Nx.Backend',
                        'Elixir.Nx.Batch','Elixir.Nx.BinaryBackend',
                        'Elixir.Nx.BinaryBackend.Matrix',
                        'Elixir.Nx.Constants','Elixir.Nx.Container',
                        'Elixir.Nx.Container.Any',
                        'Elixir.Nx.Container.Complex',
                        'Elixir.Nx.Container.Float',
                        'Elixir.Nx.Container.Integer',
                        'Elixir.Nx.Container.Map',
                        'Elixir.Nx.Container.Nx.Tensor',
                        'Elixir.Nx.Container.Tuple','Elixir.Nx.Defn',
                        'Elixir.Nx.Defn.Compiler','Elixir.Nx.Defn.Composite',
                        'Elixir.Nx.Defn.Debug','Elixir.Nx.Defn.Evaluator',
                        'Elixir.Nx.Defn.Expr','Elixir.Nx.Defn.Grad',
                        'Elixir.Nx.Defn.Kernel','Elixir.Nx.Defn.Stream',
                        'Elixir.Nx.Defn.TemplateDiff','Elixir.Nx.Defn.Token',
                        'Elixir.Nx.Defn.Tree','Elixir.Nx.Heatmap',
                        'Elixir.Nx.HiddenServing','Elixir.Nx.LazyContainer',
                        'Elixir.Nx.LazyContainer.Any',
                        'Elixir.Nx.LazyContainer.Atom',
                        'Elixir.Nx.LazyContainer.Complex',
                        'Elixir.Nx.LazyContainer.Float',
                        'Elixir.Nx.LazyContainer.Integer',
                        'Elixir.Nx.LazyContainer.List',
                        'Elixir.Nx.LazyContainer.Map',
                        'Elixir.Nx.LazyContainer.Nx.Batch',
                        'Elixir.Nx.LazyContainer.Nx.Tensor',
                        'Elixir.Nx.LazyContainer.Tuple','Elixir.Nx.LinAlg',
                        'Elixir.Nx.LinAlg.Cholesky','Elixir.Nx.LinAlg.Eigh',
                        'Elixir.Nx.LinAlg.QR','Elixir.Nx.LinAlg.SVD',
                        'Elixir.Nx.Random','Elixir.Nx.Serving',
                        'Elixir.Nx.Serving.Default','Elixir.Nx.Shape',
                        'Elixir.Nx.Shared','Elixir.Nx.Stream',
                        'Elixir.Nx.Stream.Nx.Defn.Stream',
                        'Elixir.Nx.TemplateBackend','Elixir.Nx.Tensor',
                        'Elixir.Nx.Type']},
              {compile_env,[{nx,[verify_binary_size],error},
                            {nx,[verify_grad],error}]},
              {optional_applications,[]},
              {applications,[kernel,stdlib,elixir,logger,complex,telemetry]},
              {description,"Multi-dimensional arrays (tensors) and numerical definitions for Elixir"},
              {registered,[]},
              {vsn,"0.7.3"},
              {mod,{'Elixir.Nx.Application',[]}},
              {env,[{default_backend,{'Elixir.Nx.BinaryBackend',[]}},
                    {default_defn_options,[]}]}]}.
