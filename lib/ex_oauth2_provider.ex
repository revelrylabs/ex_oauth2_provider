defmodule ExOauth2Provider do
  @moduledoc """
  A module that provides OAuth 2 capabilities for Elixir applications.

  ## Configuration
      config :ex_oauth2_provider, ExOauth2Provider,
        repo: App.Repo,
        resource_owner: App.User,
        application_resource_owner: App.User,
        default_scopes: ~w(public),
        optional_scopes: ~w(write update),
        native_redirect_uri: "urn:ietf:wg:oauth:2.0:oob",
        authorization_code_expires_in: 600,
        access_token_expires_in: 7200,
        use_refresh_token: false,
        revoke_refresh_token_on_use: false,
        force_ssl_in_redirect_uri: true,
        grant_flows: ~w(authorization_code client_credentials)

  If `revoke_refresh_token_on_use` is set to true,
  refresh tokens will be revoked after a related access token is used.

  If `revoke_refresh_token_on_use` is not set to true,
  previous tokens are revoked as soon as a new access token is created.
  """

  @config Application.get_env(:ex_oauth2_provider, ExOauth2Provider, Application.get_env(:phoenix_oauth2_provider, PhoenixOauth2Provider, []))
  @repo   Keyword.get(@config, :repo)

  @doc """
  Authenticate an access token.

  ## Example
      ExOauth2Provider.authenticate_token("Jf5rM8hQBc")
  ## Response
      {:ok, access_token}
      {:error, reason}
  """
  @spec authenticate_token(String.t) :: {:ok, map} |
                                        {:error, any}
  def authenticate_token(nil), do: {:error, :token_inaccessible}
  def authenticate_token(token, config \\ ExOauth2Provider.Config) do
    token
    |> load_access_token
    |> revoke_previous_refresh_token(config.refresh_token_revoked_on_use?)
    |> validate_access_token
    |> load_resource
  end

  defp load_access_token(token) do
    case ExOauth2Provider.OauthAccessTokens.get_by_token(token) do
      nil          -> {:error, :token_not_found}
      access_token -> {:ok, access_token}
    end
  end

  defp validate_access_token({:error, _} = error), do: error
  defp validate_access_token({:ok, access_token}) do
    case ExOauth2Provider.OauthAccessTokens.is_accessible?(access_token) do
      true -> {:ok, access_token}
      _    -> {:error, :token_inaccessible}
    end
  end

  defp load_resource({:error, _} = error), do: error
  defp load_resource({:ok, access_token}) do
    access_token = repo().preload(access_token, :resource_owner)

    case access_token.resource_owner do
      nil -> {:error, :no_association_found}
      _   -> {:ok, access_token}
    end
  end

  defp revoke_previous_refresh_token({:error, _} = error, _), do: error
  defp revoke_previous_refresh_token({:ok, _} = params, false), do: params
  defp revoke_previous_refresh_token({:ok, access_token}, true) do
    case ExOauth2Provider.OauthAccessTokens.revoke_previous_refresh_token(access_token) do
      nil -> {:error, :no_association_found}
      _   -> {:ok, access_token}
    end
  end

  @doc false
  def config, do: @config
  @doc false
  def repo, do: @repo
end
