defmodule UserManager.Authenticate.AuthenticateUserTokenGenerate do
  @moduledoc false
   use GenStage
    require Logger
    alias UserManager.User
    alias UserManager.Repo
    import Ecto.Query
    def start_link(setup) do
      GenStage.start_link(__MODULE__, [], [name: __MODULE__])
    end
    def init(state) do
      {:producer_consumer, [], subscribe_to: [UserManager.Authenticate.AuthenticateUserValidation]}
    end
    @doc"""
    generates user tokens

    ## Examples
      iex>name = Faker.Name.first_name <> Faker.Name.last_name
      iex>email = Faker.Internet.email
      iex>{:ok, user} = UserManager.UserManagerApi.create_user(name, "secretpassword", email)
      iex>{:noreply, response, _state} = UserManager.Authenticate.AuthenticateUserTokenGenerate.handle_events([{:authenticate_user, user, :browser, nil}], nil, [])
      iex>Enum.at(Tuple.to_list(Enum.at(response, 0)), 0)
      :ok
"""
    def handle_events(events, from, state) do
        process_events = events |> UserManager.WorkflowProcessing.get_process_events(:authenticate_user)
        |> Flow.from_enumerable
        |> Flow.map(fn e -> process_event(e) end)
        |> Enum.to_list
        un_process_events = UserManager.WorkflowProcessing.get_unprocessed_events(events, :authenticate_user)
        {:noreply, process_events ++ un_process_events, state}
    end
    @spec group_permissions(List.t) :: Map.t
    defp group_permissions(user_permission_list) do
      Enum.group_by(user_permission_list, fn x ->
        permission = Repo.preload(x, :permission_group)
        String.to_atom(permission.permission_group.name)
        end, fn x -> String.to_atom(x.name) end)
    end
    defp process_event({:authenticate_user, user, source, notify}) do
      u = Repo.preload(user, :permissions)
      permissions = group_permissions(u.permissions)
      case Guardian.encode_and_sign(u, source, %{"perms" => permissions}) do
        {:ok, jtw, data} -> {:ok, notify, jtw}
        {:error, :token_storage_failure} -> {:token_storage_failure, notify}
        {:error, reason} -> {:token_error, notify, reason}
      end
    end
end
