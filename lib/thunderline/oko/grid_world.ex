defmodule Thunderline.OKO.GridWorld do
  @moduledoc """
  OKO GridWorld - 3D Spatial Coordinate System integrated with Google Maps/Earth

  This module handles the conversion between:
  - Real-world GPS coordinates (lat/lng)
  - 3D voxel grid positions (x/y/z)
  - PAC spatial positioning and movement

  PACs can roam freely in virtual 3D space while remaining tethered to real-world locations.
  Enhanced with Graphmath for advanced 3D mathematical operations.
  """

  use Ash.Resource,
    domain: Thunderline.Domain,
    data_layer: AshPostgres.DataLayer

  # Import Graphmath for 3D vector operations
  alias Graphmath.Vec3
  alias Graphmath.Mat44

  @derive {Jason.Encoder,
           only: [:id, :pac_id, :lat, :lng, :x, :y, :z, :region_id, :tick_id, :timestamp]}

  postgres do
    table "oko_grid_positions"
    repo Thunderline.Repo
  end

  attributes do
    uuid_primary_key :id

    # Real-world GPS coordinates
    attribute :lat, :float do
      description "Latitude coordinate (Google Maps compatible)"
      allow_nil? false
    end

    attribute :lng, :float do
      description "Longitude coordinate (Google Maps compatible)"
      allow_nil? false
    end

    # 3D Virtual grid coordinates
    attribute :x, :float do
      description "X coordinate in 3D voxel grid"
      allow_nil? false
    end

    attribute :y, :float do
      description "Y coordinate in 3D voxel grid"
      allow_nil? false
    end

    attribute :z, :float do
      description "Z coordinate in 3D voxel grid (elevation/layer)"
      allow_nil? false
    end

    # PAC and positioning metadata
    attribute :pac_id, :uuid do
      description "ID of the PAC at this position"
      allow_nil? false
    end

    attribute :region_id, :string do
      description "Regional zone identifier"
      allow_nil? false
    end

    attribute :tick_id, :integer do
      description "Tick ID when position was recorded"
      allow_nil? false
    end

    attribute :timestamp, :utc_datetime_usec do
      description "Precise timestamp of position update"
      allow_nil? false
      default &DateTime.utc_now/0
    end

    # Additional metadata
    attribute :heading, :float do
      description "Direction PAC is facing (0-360 degrees)"
      default 0.0
    end

    attribute :velocity, :float do
      description "PAC movement speed"
      default 0.0
    end

    attribute :elevation_meters, :float do
      description "Real-world elevation in meters"
      default 0.0
    end

    timestamps()
  end

  actions do
    defaults [:create, :read, :update, :destroy]

    create :place_pac do
      description "Place PAC at specific coordinates"

      accept [
        :pac_id,
        :lat,
        :lng,
        :x,
        :y,
        :z,
        :region_id,
        :tick_id,
        :heading,
        :velocity,
        :elevation_meters
      ]
    end

    read :get_pac_position do
      description "Get current position of specific PAC"
      argument :pac_id, :uuid, allow_nil?: false

      filter expr(pac_id == ^arg(:pac_id))

      prepare fn query, _context ->
        query
        |> Ash.Query.sort(timestamp: :desc)
        |> Ash.Query.limit(1)
      end
    end

    read :get_region_pacs do
      description "Get all PACs in a specific region"
      argument :region_id, :string, allow_nil?: false

      filter expr(region_id == ^arg(:region_id))

      prepare fn query, _context ->
        Ash.Query.sort(query, timestamp: :desc)
      end
    end

    update :move_pac do
      description "Update PAC position"
      accept [:lat, :lng, :x, :y, :z, :heading, :velocity, :tick_id]

      change fn changeset, _context ->
        changeset
        |> Ash.Changeset.change_attribute(:timestamp, DateTime.utc_now())
      end
    end
  end

  # Coordinate conversion functions
  def gps_to_grid(lat, lng, base_lat \\ 0.0, base_lng \\ 0.0) do
    # Convert GPS coordinates to 3D grid positions
    # Each degree ≈ 111km, scale to reasonable grid units
    # meters from base longitude
    x = (lng - base_lng) * 111_000
    # meters from base latitude
    y = (lat - base_lat) * 111_000
    # Ground level by default
    z = 0.0

    {x, y, z}
  end

  def grid_to_gps(x, y, z \\ 0.0, base_lat \\ 0.0, base_lng \\ 0.0) do
    # Convert 3D grid positions back to GPS coordinates
    lat = base_lat + y / 111_000
    lng = base_lng + x / 111_000
    # Z becomes elevation in meters
    elevation = z

    {lat, lng, elevation}
  end

  def calculate_distance(lat1, lng1, lat2, lng2) do
    # Haversine formula for distance between GPS coordinates
    dlat = :math.pi() * (lat2 - lat1) / 180
    dlng = :math.pi() * (lng2 - lng1) / 180

    a =
      :math.sin(dlat / 2) * :math.sin(dlat / 2) +
        :math.cos(:math.pi() * lat1 / 180) * :math.cos(:math.pi() * lat2 / 180) *
          :math.sin(dlng / 2) * :math.sin(dlng / 2)

    c = 2 * :math.atan2(:math.sqrt(a), :math.sqrt(1 - a))

    # Earth radius in km
    6371 * c
  end

  ## Enhanced 3D Operations with Graphmath

  @doc """
  Calculate 3D Euclidean distance between two grid positions using Graphmath.
  """
  def calculate_3d_distance({x1, y1, z1}, {x2, y2, z2}) do
    vec1 = Vec3.create(x1, y1, z1)
    vec2 = Vec3.create(x2, y2, z2)
    distance_vec = Vec3.subtract(vec2, vec1)
    Vec3.length(distance_vec)
  end

  @doc """
  Calculate movement vector between two 3D positions.
  Returns normalized direction vector.
  """
  def calculate_movement_vector({x1, y1, z1}, {x2, y2, z2}) do
    vec1 = Vec3.create(x1, y1, z1)
    vec2 = Vec3.create(x2, y2, z2)
    direction = Vec3.subtract(vec2, vec1)
    Vec3.normalize(direction)
  end

  @doc """
  Rotate a 3D position around a given axis and angle (in radians).
  """
  def rotate_position({x, y, z}, {axis_x, axis_y, axis_z}, angle_radians) do
    position = Vec3.create(x, y, z)
    axis = Vec3.create(axis_x, axis_y, axis_z) |> Vec3.normalize()

    # Create rotation matrix
    rotation_matrix = Mat44.make_rotate(angle_radians, axis)

    # Apply rotation
    rotated = Mat44.transform_point3(rotation_matrix, position)
    {rotated.x, rotated.y, rotated.z}
  end

  @doc """
  Calculate interpolated position between two 3D points.
  t should be between 0.0 and 1.0.
  """
  def interpolate_position({x1, y1, z1}, {x2, y2, z2}, t) when t >= 0.0 and t <= 1.0 do
    vec1 = Vec3.create(x1, y1, z1)
    vec2 = Vec3.create(x2, y2, z2)
    interpolated = Vec3.lerp(vec1, vec2, t)
    {interpolated.x, interpolated.y, interpolated.z}
  end

  @doc """
  Check if a position is within a spherical region.
  """
  def within_sphere?({x, y, z}, {center_x, center_y, center_z}, radius) do
    distance = calculate_3d_distance({x, y, z}, {center_x, center_y, center_z})
    distance <= radius
  end

  @doc """
  Calculate the cross product of two 3D vectors (useful for collision detection).
  """
  def cross_product({x1, y1, z1}, {x2, y2, z2}) do
    vec1 = Vec3.create(x1, y1, z1)
    vec2 = Vec3.create(x2, y2, z2)
    result = Vec3.cross(vec1, vec2)
    {result.x, result.y, result.z}
  end
end
