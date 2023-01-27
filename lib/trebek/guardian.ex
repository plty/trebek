defmodule Trebek.Guardian.User do
  defstruct [:id, :username]
end

defmodule Trebek.Guardian do
  use Guardian, otp_app: :trebek

  def subject_for_token(resource = %{id: id}, claims) do
    # You can use any value for the subject of your token but
    # it should be useful in retrieving the resource later, see
    # how it being used on `resource_from_claims/1` function.
    # A unique `id` is a good subject, a non-unique email address
    # is a poor subject.
    IO.inspect(["SUBJECT FOR TOKEN", resource, claims])
    sub = to_string(id)
    {:ok, sub}
  end

  def resource_from_claims(claims = %{"sub" => _id}) do
    # Here we'll look up our resource from the claims, the subject can be
    # found in the `"sub"` key. In above `subject_for_token/2` we returned
    # the resource id so here we'll rely on that to look it up.
    IO.inspect(["RESOURCE FROM CLAIMS", claims])
    {:ok, %Trebek.Guardian.User{id: claims["id"], username: claims["username"]}}
  end
end
