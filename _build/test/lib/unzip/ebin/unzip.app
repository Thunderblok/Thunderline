{application,unzip,
             [{modules,['Elixir.Unzip','Elixir.Unzip.Entry',
                        'Elixir.Unzip.Error','Elixir.Unzip.FileAccess',
                        'Elixir.Unzip.FileAccess.BitString',
                        'Elixir.Unzip.FileAccess.Unzip.LocalFile',
                        'Elixir.Unzip.FileBuffer','Elixir.Unzip.LocalFile',
                        'Elixir.Unzip.RangeTree']},
              {optional_applications,[]},
              {applications,[kernel,stdlib,elixir,logger]},
              {description,"Elixir library to stream zip file contents. Works with remote files. Supports Zip64"},
              {registered,[]},
              {vsn,"0.10.0"}]}.
