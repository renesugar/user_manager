defmodule UserManager.CreateUser.CreateUserPermissions do
  @moduledoc false
  use GenStage
  alias UserManager.Schemas.Permission
  alias UserManager.Schemas.PermissionGroup
  alias UserManager.Repo
  import Ecto.Query
  import Ecto.Changeset
  require Logger
   def start_link(setup) do
     name = "#{__MODULE__}#{setup}"
      GenStage.start_link(__MODULE__, [], name: __MODULE__)
  end
  def init(stat) do
    {:producer_consumer, [], subscribe_to: [UserManager.CreateUser.CreateUserRepoInsert]}
  end
  defp get_permission_from_state({group, per_list}) do
    g = PermissionGroup
    |> where(name: ^Atom.to_string(group))
    |> Repo.one!
    |> Repo.preload(:permissions)
    Enum.flat_map(per_list, fn l ->
      Enum.filter(g.permissions, fn p -> p.name == Atom.to_string(l) end)
     end)
  end
  @doc"""

  responsible for attaching default permissions to users

  ##Examples
    iex>userchangeset =UserManager.Schemas.User.changeset( %UserManager.Schemas.User{}, %{})
    iex>{:noreply, response, state} = UserManager.CreateUser.CreateUserRepoInsert.handle_events([{:insert_user, userchangeset, nil}], self(), [])
    iex>user = Enum.at(Tuple.to_list(Enum.at(response,0)),1)
    iex>{:noreply, response, state} = UserManager.CreateUser.CreateUserPermissions.handle_events([{:insert_permissions, user, nil}], self(), [])
    iex>Enum.at(Tuple.to_list(Enum.at(response,0)),0)
    :ok

"""
  def handle_events(events, from, state) do
    state = case (state == []) do
      true -> default_create_permissions = Map.to_list(Application.get_env(:user_manager, :new_user_default_permissions))
              Enum.flat_map(default_create_permissions, fn p -> get_permission_from_state(p) end)
      false -> state
    end
    process_events =  events |> UserManager.WorkflowProcessing.get_process_events(:insert_permissions)
     |> Flow.from_enumerable
     |> Flow.map(fn e ->
        {:insert_permissions, user, notify} = e
        event_permissions_inserts = Stream.map(state, fn p ->
          permission = Repo.preload(p, :users)
          user_list = [user | permission.users]
           changeset = permission |> Permission.changeset(%{}) |> put_assoc(:users, user_list)
           update_repo(changeset)
         end)
         {e, event_permissions_inserts}
      end)
      |> Flow.map(fn e ->
        {{:insert_permissions, user, notify}, event_permissions_inserts} = e
        compile_update_result(event_permissions_inserts, user, notify)
       end)
      |> Enum.to_list
      unprocessed_events =  UserManager.WorkflowProcessing.get_unprocessed_events(events, :insert_permissions)
    {:noreply, process_events ++ unprocessed_events, state}
  end
  defp update_repo(changeset) do
    case Repo.update(changeset) do
      {:ok, update_permission} -> {:ok, update_permission}
      {:error, changeset} -> {:update_error, changeset}
     end
  end
  defp compile_update_result(event_permissions_inserts, user, notify) do
    Enum.reduce_while(event_permissions_inserts, {:ok, notify, user}, fn p, acc ->
      case p do
        {:ok, _} -> {:cont, acc}
        {:update_error, changeset} -> {:halt, {:update_permission_error, notify, changeset.errors}}
      end
     end)
  end
end
