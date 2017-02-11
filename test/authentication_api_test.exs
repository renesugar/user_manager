defmodule AuthenticationApiTest do
  use ExUnit.Case
    alias UserManager.Repo
    alias UserManager.Schemas.User
    require Logger
    setup_all do
      {:ok, user} = UserManager.UserManagerApi.create_user("testuser1", "testpassword1", Faker.Internet.email)
      :ok
    end
    test "authenticate and identify user" do
      {:ok, _} = UserManager.UserManagerApi.authenticate_user("testuser1", "testpassword1")
    end
    test "identify user" do
      {:ok, token} = UserManager.UserManagerApi.authenticate_user("testuser1", "testpassword1")
      {:ok, user} = UserManager.UserManagerApi.identify_user(token)
      assert user != nil
      assert user.id > 0
      user = user |> Repo.preload(:user_profile)
      assert user.user_profile.name == "testuser1"
      assert Comeonin.Bcrypt.checkpw("testpassword1", user.user_profile.password)
    end
    test "invalid authenticate" do
      {:error, :authenticate_failure} = UserManager.UserManagerApi.authenticate_user("testuser1", "")
      {:error, :user_not_found} = UserManager.UserManagerApi.authenticate_user("", "testpassword1")
      {:error, :user_not_found} = UserManager.UserManagerApi.authenticate_user("fdsafdsa", "fdsfdas")
    end
    test "invalid identify" do
      {:error, :token_decode_error, _} = UserManager.UserManagerApi.identify_user("fjkdsfkljasfkjlas")
    end
    test "valid token not saved identify" do
         token = "eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJVc2VyOjQiLCJleHAiOjE0ODkzMDMyMTksImlhdCI6MTQ4NjcxMTIxOSwiaXNzIjoiU29tZW9uZSIsImp0aSI6Ijg0NGUwY2EzLWM4ZWUtNDQ3Mi1iMzYxLWVhODdjNGUzYjU3NCIsInBlbSI6eyJkZWZhdWx0IjoxfSwic3ViIjoiVXNlcjo0IiwidHlwIjoiYnJvd3NlciJ9.nA3-dkFNqTW1GYO8x1v9zTQoUk6ddyK2FqgZPZk9k6lO_iIOQx6We35ItLEeRAZO_5lv9JR4WWizQ7J7p8HRcA"
        {:error, :token_not_found} = UserManager.UserManagerApi.identify_user(token)
    end
end