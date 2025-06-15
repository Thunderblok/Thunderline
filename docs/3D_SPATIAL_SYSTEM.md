# 🌐 Thunderline 3D Spatial System Documentation

## Overview

Thunderline features a comprehensive 3D spatial coordinate system that enables PAC agents to exist in both virtual 3D space and real-world GPS coordinates simultaneously. This system is enhanced with **Graphmath** for advanced mathematical operations.

## Architecture Components

### 🎯 Core Modules

#### 1. `Thunderline.OKO.GridWorld`
**Primary 3D coordinate system with Graphmath integration**

**Capabilities:**
- Dual coordinate mapping (GPS ↔ 3D Grid)
- Real-time PAC position tracking
- Advanced 3D mathematical operations
- Regional coordinate management

**Key Functions:**
```elixir
# Basic coordinate conversion
{x, y, z} = GridWorld.gps_to_grid(lat, lng)
{lat, lng, elevation} = GridWorld.grid_to_gps(x, y, z)

# Enhanced 3D operations (Graphmath powered)
distance = GridWorld.calculate_3d_distance(pos1, pos2)
direction = GridWorld.calculate_movement_vector(start, target)
rotated_pos = GridWorld.rotate_position(position, axis, angle)
smooth_pos = GridWorld.interpolate_position(pos1, pos2, 0.5)

# Spatial queries
in_range? = GridWorld.within_sphere?(position, center, radius)
cross_vec = GridWorld.cross_product(vec1, vec2)
```

#### 2. `Thunderline.GridWorld.MapCoordinate`
**GPS-Grid coordinate mapping with temporal tracking**

**Features:**
- High-precision GPS coordinates (decimal)
- Integer-based 3D grid coordinates  
- Tick-synchronized updates
- Region/zone organization
- Google Maps integration metadata

**Enhanced Functions:**
```elixir
# 3D distance between coordinates
distance = MapCoordinate.grid_distance_3d(coord1, coord2)

# Movement vector calculation
{x, y, z} = MapCoordinate.movement_vector_3d(from, to)

# Smooth interpolation between coordinates
intermediate = MapCoordinate.interpolate_3d(coord1, coord2, 0.3)
```

#### 3. `ThunderlineWeb.MapLive`
**Real-time 3D visualization and control interface**

**Features:**
- Google Maps integration with 3D grid overlay
- Live PAC tracking and positioning
- Interactive placement and movement
- Regional coordination display

## Graphmath Integration

### Why Graphmath?

**Graphmath** is a pure Elixir 3D mathematics library that provides:
- **Performance**: Optimized vector and matrix operations
- **Precision**: IEEE floating-point compliance
- **Integration**: Seamless Elixir ecosystem compatibility
- **Features**: Comprehensive 3D math toolkit

### Mathematical Operations Available

#### Vector Operations
```elixir
# Create 3D vectors
vec1 = Vec3.create(10.0, 20.0, 30.0)
vec2 = Vec3.create(5.0, 10.0, 15.0)

# Basic operations
sum = Vec3.add(vec1, vec2)
difference = Vec3.subtract(vec1, vec2)
scaled = Vec3.scale(vec1, 2.0)

# Advanced operations
length = Vec3.length(vec1)
normalized = Vec3.normalize(vec1)
dot_product = Vec3.dot(vec1, vec2)
cross_product = Vec3.cross(vec1, vec2)
interpolated = Vec3.lerp(vec1, vec2, 0.5)
```

#### Matrix Transformations
```elixir
# Create transformation matrices
translation = Mat44.make_translate(10.0, 0.0, 5.0)
rotation = Mat44.make_rotate(math.pi/4, Vec3.create(0, 1, 0))
scale = Mat44.make_scale(2.0, 2.0, 2.0)

# Combine transformations
transform = Mat44.multiply(translation, rotation)

# Apply to positions
new_position = Mat44.transform_point3(transform, position)
```

## Coordinate System Design

### Grid Space
- **Origin**: Configurable per region
- **Units**: 1 grid unit ≈ 1 meter
- **Range**: Integer coordinates (memory efficient)
- **Precision**: Suitable for game/simulation mechanics

### GPS Space  
- **Format**: Decimal degrees (WGS84)
- **Precision**: Sub-meter accuracy
- **Integration**: Google Maps, real-world mapping
- **Conversion**: Automatic bidirectional mapping

### Example Conversions
```elixir
# New York City coordinates
{lat, lng} = {40.7128, -74.0060}

# Convert to grid (relative to region origin)
{x, y, z} = GridWorld.gps_to_grid(lat, lng)
# Result: {x: 152340, y: 87234, z: 0}

# Convert back to GPS
{lat_back, lng_back, elevation} = GridWorld.grid_to_gps(x, y, z)
# Result: {40.7128, -74.0060, 0.0}
```

## Real-time Integration

### Tick System Integration
PAC positions are updated during tick cycles:

```elixir
# During agent tick processing
def handle_agent_movement(agent, new_position) do
  # Update position in GridWorld
  GridWorld.place_pac(%{
    pac_id: agent.id,
    lat: lat, lng: lng,
    x: x, y: y, z: z,
    tick_id: current_tick
  })
  
  # Broadcast to live viewers
  Phoenix.PubSub.broadcast(PubSub, "pac_movements", 
    {:pac_moved, agent.id, new_position})
end
```

### LiveView Integration
Real-time updates flow to the web interface:

```elixir
# In MapLive
def handle_info({:pac_moved, pac_id, position}, socket) do
  {:noreply, 
   socket
   |> update_pac_position(pac_id, position)
   |> push_to_javascript_map()}
end
```

## Performance Considerations

### Optimizations
- **Integer Grid Coordinates**: Efficient storage and comparison
- **Spatial Indexing**: Database indexes on grid coordinates
- **Regional Batching**: Group updates by geographic region
- **Tick Throttling**: Position updates every N ticks (configurable)

### Scalability Features
- **Regional Governors**: Distributed coordinate management
- **PubSub Broadcasting**: Efficient real-time updates
- **Database Partitioning**: Regional data separation
- **Caching Layers**: Frequently accessed position data

## Usage Examples

### 1. PAC Movement System
```elixir
defmodule PAC.MovementSystem do
  alias Thunderline.OKO.GridWorld

  def move_pac_towards_target(pac_id, target_position) do
    current_pos = get_pac_position(pac_id)
    
    # Calculate movement vector
    direction = GridWorld.calculate_movement_vector(current_pos, target_position)
    
    # Apply movement speed
    movement_speed = 5.0  # units per tick
    movement_vec = Vec3.scale(direction, movement_speed)
    
    # Calculate new position
    new_position = Vec3.add(current_pos, movement_vec)
    
    # Update position
    update_pac_position(pac_id, new_position)
  end
end
```

### 2. Proximity Detection
```elixir
defmodule PAC.ProximitySystem do
  def find_nearby_pacs(pac_id, radius \\ 100.0) do
    pac_position = get_pac_position(pac_id)
    all_pacs = get_all_pac_positions()
    
    Enum.filter(all_pacs, fn {other_id, other_pos} ->
      other_id != pac_id and 
      GridWorld.within_sphere?(other_pos, pac_position, radius)
    end)
  end
end
```

### 3. Smooth Path Following
```elixir
defmodule PAC.PathSystem do
  def follow_path(pac_id, waypoints, progress) do
    # Find current segment
    segment_index = trunc(progress * (length(waypoints) - 1))
    local_progress = rem(progress * (length(waypoints) - 1), 1.0)
    
    # Get waypoints for interpolation
    point_a = Enum.at(waypoints, segment_index)
    point_b = Enum.at(waypoints, segment_index + 1)
    
    # Interpolate position
    current_position = GridWorld.interpolate_position(
      point_a, point_b, local_progress
    )
    
    update_pac_position(pac_id, current_position)
  end
end
```

## Future Enhancements

### Planned Features
- **Physics Integration**: Velocity, acceleration, collision detection
- **Terrain System**: Height maps and obstacle avoidance
- **Multi-layer Grids**: Different resolution levels (macro/micro)
- **Distributed Coordination**: Cross-region PAC interactions
- **AR/VR Integration**: Real-world overlay capabilities

### Mathematical Extensions
- **Quaternion Support**: Smooth 3D rotations
- **Spline Interpolation**: Advanced path smoothing
- **Spatial Algorithms**: A* pathfinding, visibility graphs
- **Physics Simulation**: Rigid body dynamics

## Configuration

### Environment Setup
```elixir
# config/config.exs
config :thunderline, :spatial,
  default_region_origin: {40.7128, -74.0060},  # NYC
  grid_scale: 1.0,  # 1 meter per grid unit
  update_frequency: 2,  # Every 2 ticks
  max_render_distance: 1000.0  # meters
```

### Database Schema
```sql
-- Grid positions table
CREATE TABLE oko_grid_positions (
  id UUID PRIMARY KEY,
  pac_id UUID NOT NULL,
  lat FLOAT NOT NULL,
  lng FLOAT NOT NULL,
  x FLOAT NOT NULL,
  y FLOAT NOT NULL,
  z FLOAT NOT NULL,
  region_id VARCHAR NOT NULL,
  tick_id INTEGER NOT NULL,
  timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Spatial indexes for performance
CREATE INDEX idx_grid_positions_region ON oko_grid_positions(region_id);
CREATE INDEX idx_grid_positions_spatial ON oko_grid_positions(x, y, z);
CREATE INDEX idx_grid_positions_pac ON oko_grid_positions(pac_id);
```

## Troubleshooting

### Common Issues
1. **Coordinate Drift**: Ensure proper region origins
2. **Performance**: Monitor database query performance
3. **Synchronization**: Verify tick timing consistency
4. **Precision**: Check floating-point accumulation errors

### Debugging Tools
```elixir
# Coordinate validation
GridWorld.validate_coordinates(position)

# Distance verification
expected_distance = 100.0
actual_distance = GridWorld.calculate_3d_distance(pos1, pos2)
assert abs(expected_distance - actual_distance) < 0.1

# Performance monitoring
:timer.tc(fn -> GridWorld.calculate_movement_vector(pos1, pos2) end)
```

This 3D spatial system provides the foundation for sophisticated agent behaviors, real-world integration, and scalable multi-agent coordination in the Thunderline substrate.
