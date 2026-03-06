defmodule A2UI.Surface do
  @moduledoc """
  Represents an A2UI rendering surface.

  A surface holds the component adjacency list, data model, theme,
  and configuration for a single A2UI surface instance.
  """

  alias A2UI.DataModel

  defstruct [
    :id,
    :catalog_id,
    theme: %{},
    send_data_model: false,
    components: %{},
    data_model: %DataModel{}
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          catalog_id: String.t(),
          theme: map(),
          send_data_model: boolean(),
          components: %{String.t() => A2UI.Component.t()},
          data_model: DataModel.t()
        }
end
