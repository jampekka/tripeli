from sympy import *

var("closeness distance target_radius base_radius shrapnels shrapnel_radius shot_std", positive=True, nonzero=True, real=True)
var("hit_reward miss_reward shrapnel_reward shot_bias", real=True)
var("x")
# TODO: Small angle

defaults = {
    target_radius: 0.07,
    base_radius: 0.1,
    shrapnel_radius: 0.01,
    shrapnels: 6,
    shot_std: 5/180*pi,
    hit_reward: 1,
    miss_reward: -1,
    shrapnel_reward: -1
        }

shot_bias = 0


hit_reward = 1
miss_reward = -hit_reward
shrapnel_reward = -hit_reward


#distance = exp(closeness)
distance = 1/closeness
#distance = 1/closeness

target_radius = base_radius


angular_target_radius = asin(target_radius/distance)
base_angular_extent = asin((base_radius + shrapnel_radius)/distance)*2
# Small angle approximations of tan
#angular_target_radius = target_radius/distance
#base_angular_extent = base_radius/distance*2


shot_hit_cdf = (1 + erf((x - shot_bias)/(shot_std*sqrt(2))))/2
shot_hit_p = shot_hit_cdf.subs({x: angular_target_radius}) - shot_hit_cdf.subs({x: -angular_target_radius})

shrapnel_angular_extent = 2*pi/shrapnels
shrapnel_hit_p = base_angular_extent/shrapnel_angular_extent

shot_miss_p = 1 - shot_hit_p
shrapnel_p = shrapnel_hit_p*shot_hit_p

print(shot_hit_p)
print(shrapnel_hit_p)

expected_value = shot_hit_p*hit_reward + shot_miss_p*miss_reward + shrapnel_p*shrapnel_reward

pprint(expected_value.diff(closeness).expand().simplify())

#pprint(solve(simplify(expected_value).diff(closeness), closeness))
#pprint(expected_value.diff(closeness))

#wtf = expected_value.subs(defaults)#.subs({closeness: log(closeness)})
#plot(wtf, (closeness, 0.1, 1))
#pprint(solve(simplify(expected_value.subs(defaults)), closeness))

#plot(expected_value.diff(closeness).subs(defaults))
#ddist = expected_value.diff(distance)
#pprint(solve(ddist, distance))
