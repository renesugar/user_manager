defmodule UserManager.Authenticate.AuthenticateUserValidation do
  @moduledoc false
  use GenStage
  require Logger
  alias UserManager.Schemas.User
  alias UserManager.Repo
  import Ecto.Query
  alias Comeonin.Bcrypt
  def start_link(setup) do
    GenStage.start_link(__MODULE__, [], [name: __MODULE__])
  end
  def init(state) do
    {:producer_consumer, [], subscribe_to: [UserManager.Authenticate.AuthenticateUserUserLookup]}
  end
  @doc"""
  validates user input vs encrypted db field

  iex>name = Faker.Name.first_name <> Faker.Name.last_name
  iex>email = Faker.Internet.email
  iex>{:ok, user} = UserManager.UserManagerApi.create_user(name, "secretpassword", email)
  iex>{:noreply, response, _state} = UserManager.Authenticate.AuthenticateUserValidation.handle_events([{:validate_user, user, "secretpassword", :browser, nil}], nil, [])
  iex> Enum.at(Tuple.to_list(Enum.at(response, 0)), 0)
  :authenticate_user

  iex>name = Faker.Name.first_name <> Faker.Name.last_name
  iex>email = Faker.Internet.email
  iex>{:ok, user} = UserManager.UserManagerApi.create_user(name, "secretpassword", email)
  iex>{:noreply, response, _state} = UserManager.Authenticate.AuthenticateUserValidation.handle_events([{:validate_user, user, "secretpassworda", :browser, nil}], nil, [])
  iex> Enum.at(Tuple.to_list(Enum.at(response, 0)), 0)
  :authenticate_failure
"""
  def handle_events(events, from, state) do
    process_events = events |> UserManager.WorkflowProcessing.get_process_events(:validate_user)
    |> Flow.from_enumerable
    |> Flow.map(fn {:validate_user, user, password, source, notify} ->
      pass = user.user_profile.authentication_metadata |> Map.fetch!("credentials") |> Map.fetch!("password")
      authenticate_user(password, pass, user, source, notify)
     end)
     |> Enum.to_list
     un_processed_events = UserManager.WorkflowProcessing.get_unprocessed_events(events, :validate_user)
      {:noreply, process_events ++ un_processed_events, state}
  end
  defp authenticate_user(input_password, encrypted_password, user, source, notify) do
    Logger.debug "input: #{inspect input_password}, encrypt: #{inspect encrypted_password}"
    case Bcrypt.checkpw(input_password, encrypted_password) do
      true -> {:authenticate_user, user, source, notify}
      false -> {:authenticate_failure, notify}
    end
  end

end
