import Config

config :ex_keccak, ExKeccak, skip_compilation?: true
config :explorer, Explorer.PolarsBackend.Native, skip_compilation?: true
config :ex_secp256k1, ExSecp256k1.Impl, skip_compilation?: true
config :tokenizers, Tokenizers.Native, skip_compilation?: true
