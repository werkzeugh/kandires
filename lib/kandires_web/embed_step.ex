defmodule KandiresWeb.EmbedStep do
  @moduledoc "Boilerplate for Embed Step"

  @callback process(Plug.Conn.t(), map()) :: Plug.Conn.t()

  @callback changeset_for_this_step(
              Ecto.Schema.t()
              | Ecto.Changeset.t()
              | {Ecto.Changeset.data(), Ecto.Changeset.types()},
              map()
            ) ::
              Ecto.Schema.t()
              | Ecto.Changeset.t()
              | {Ecto.Changeset.data(), Ecto.Changeset.types()}

  @optional_callbacks changeset_for_this_step: 2, process: 2

  # https://stackoverflow.com/questions/39490972/adding-default-handle-info-in-using-macro
  defmacro(__using__(_)) do
    quote do
      @checkout_key "checkout"
      @behaviour KandiresWeb.EmbedStep
      @before_compile KandiresWeb.EmbedStep

      alias KandiresWeb.Router.Helpers, as: Routes

      def super_render(assigns) do
        Phoenix.View.render(@pageview, "reservation_#{@step}.html", assigns)
      end

      def super_handle_event("validate", %{"step_data" => incoming_data}, socket) do
        changeset =
          changeset_for_this_step(incoming_data, socket.assigns)
          |> Map.put(:action, :insert)

        {:noreply, Phoenix.LiveView.assign(socket, changeset: changeset)}
      end

      def super_handle_event("save", %{"step_data" => incoming_data}, socket) do
        save_step_data(incoming_data, socket)
      end

      def super_handle_event("save", msg, socket) do
        save_step_data(%{}, socket)
      end

      def super_handle_event(event, msg, socket) do
        msg
        |> IO.inspect(label: "super handle event '#{event}' -----------------------------------")

        {:noreply, socket}
      end

      # reload page if checkout-data changed
      def super_handle_info({:visitor_session, [key, :updated], _new_data}, socket)
          when key in [@checkout_key, :all] do
        socket |> reload_current_page()
      end

      def reload_current_page(socket),
        do:
          {:noreply,
           socket
           |> Phoenix.LiveView.redirect(
             to: Kandis.Checkout.get_link_for_step(socket.assigns, @step)
           )}

      # ignore other types of messages
      def super_handle_info(msg, socket) do
        msg |> IO.inspect(label: "super handle info -----------------------------------")
        {:noreply, socket}
      end

      def save_step_data(incoming_data, socket) do
        changeset_for_this_step(incoming_data, socket.assigns)
        |> Ecto.Changeset.apply_action(:insert)
        |> case do
          {:ok, clean_incoming_data} ->
            Kandis.Checkout.update(socket.assigns.vid, clean_incoming_data)

            {:noreply,
             socket
             |> Phoenix.LiveView.redirect(
               to: Kandis.Checkout.get_next_step_link(socket.assigns, @step)
             )}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, Phoenix.LiveView.assign(socket, changeset: changeset)}
        end
      end

      def process(conn, params) do
        conn
        |> Plug.Conn.assign(:live_module, __MODULE__)
        |> Kandis.Checkout.redirect_if_empty_cart(params[:vid] || params[:visit_id], params)
      end

      def changeset_for_this_step(values, context) do
        data = %{}
        types = %{}

        {data, types}
        |> Ecto.Changeset.cast(values, Map.keys(types))
      end

      defoverridable KandiresWeb.EmbedStep
    end
  end

  # default clauses at and of code:
  defmacro __before_compile__(_) do
    quote do
      @impl Phoenix.LiveView
      def render(assigns), do: super_render(assigns)

      def dummy(), do: :dummyresponse3

      @impl Phoenix.LiveView
      def handle_event(event, msg, socket), do: super_handle_event(event, msg, socket)

      @impl Phoenix.LiveView
      def handle_info(msg, socket), do: super_handle_info(msg, socket)
    end
  end
end
