defmodule DomusWeb.Gettext do
  @moduledoc """
  A module providing Internationalization with a gettext-based API.

               "Here are the strings to translate",
               3)

      # Domain-based translation
      dgettext("errors", "Here is the error message to translate")

  See the [Gettext Docs](https://hexdocs.pm/gettext) for detailed usage.
  """
  use Gettext, otp_app: :domus
end
