"""
Mathematical models for different aspects of the Tripeli task.
"""

import numpy as np
import matplotlib.pyplot as plt
#import sympy as sp

from scipy.stats import vonmises, norm

N_SHRAPNELS=5
BASE_RADIUS = 0.1
TARGET_RADIUS = 0.1

# TODO: Verify all by simulation!

default_trial=dict(
    target_radius=0.1,
    n_shrapnels=5,
    base_radius=0.1,

    distance=0.5,

    shot_std=np.radians(5),
    shot_bias=np.radians(0),
    
    hit_reward=1,
    miss_reward=-1,
    shrapnel_reward=-1,
)

def study_hit_probability():
    """
    Trying out different approximations of the hit distribution.
    The "true" distribution is von Mises, with angle defined by arctan of radius and distance.
    
    Small angle approximation with Gaussian distribution is probably
    extremely close for any sane values in Tripeli. May get useful if we want to do
    something like a Kalman filter or other analytical results. Otherwise we can just
    use the "proper" distribution.

    We assume Normal distributed angular error, which is probably the most violated assumption
    anyway.
    """
    shot_std = np.radians(10)
    distance = 0.5
    radius = 0.1
    bias = 0.0

    angular_extent = np.arctan(radius/distance)*2
    kappa = 1/shot_std**2
    shot_angle_distribution = vonmises(loc=bias, kappa=kappa)

    anglerange = np.linspace(-np.pi, np.pi, 1000)
    plt.plot(np.degrees(anglerange), shot_angle_distribution.pdf(anglerange))
    shot_angle_norm = norm(loc=bias, scale=shot_std)
    plt.plot(np.degrees(anglerange), shot_angle_norm.pdf(anglerange))
    
    shot_angle_norm_small = norm(loc=bias, scale=shot_std)
    plt.plot(np.degrees(anglerange), shot_angle_norm.pdf(anglerange))

    plt.show()

def shot_hit_probability(distance, radius, shot_std, shot_bias=0.0):
    angular_radius = np.arctan(radius/distance)
    kappa = 1/(shot_std**2)

    hit_dist = vonmises(loc=shot_bias, kappa=kappa)
    hit_prob = hit_dist.cdf(angular_radius) - hit_dist.cdf(-angular_radius)

    return hit_prob

def shrapnel_hit_probability(distance, base_radius, n_shrapnels):
    # TODO: Account for shrapnel size
    # TODO: Verify by simulation! I don't fully understand this myself!

    angular_extent = 2*np.pi/n_shrapnels
    
    base_angular_extent = np.arctan(base_radius/distance)*2
    hit_prob = np.minimum(1.0, base_angular_extent/angular_extent)

    return hit_prob



def plot_shrapnel_hit_probability(base_radius=BASE_RADIUS):
    target_distance = np.linspace(0, 1.0, 100)[1:]
    
    n_shrapnelss = np.arange(0, 10, 1)
    for n_shrapnels in n_shrapnelss:
        hit_prob = shrapnel_hit_probability(target_distance, base_radius, n_shrapnels=n_shrapnels)
        plt.plot(target_distance, hit_prob, label=f"{n_shrapnels} shrapnels")
    plt.legend()
    plt.show()

def plot_shot_hit_probability(target_radius=TARGET_RADIUS):
    target_distance = np.linspace(0, 1.0, 100)[1:]

    shot_stds = np.radians(np.linspace(0.0, 30.0, 7)[1:])

    for shot_std in shot_stds:
        print(shot_std)
        plt.plot(target_distance, shot_hit_probability(target_distance, target_radius, shot_std), label=f"Shot std {np.degrees(shot_std):.1f}⁰")
    plt.xlabel("Target distance")
    plt.ylabel("Shot hit probability")
    plt.legend()
    plt.show()

def plot_outcome_probability(base_radius=BASE_RADIUS, target_radius=TARGET_RADIUS, n_shrapnels=N_SHRAPNELS):
    target_distance = np.linspace(0, 1.0, 100)[1:]

    shot_stds = np.radians(np.linspace(0.0, 10.0, 4)[1:])
    
    for i, shot_std in enumerate(shot_stds):
        print(shot_std)
        shot_hit_p = shot_hit_probability(target_distance, target_radius, shot_std)
        shrapnel_hit_p = shrapnel_hit_probability(target_distance, base_radius, n_shrapnels)

        # Where to handle collision "probability"?
        collision = target_distance < base_radius + target_radius
        shot_hit_p *= 1 - collision

        win_p = shot_hit_p * (1 - shrapnel_hit_p)
        shrapnel_p = shot_hit_p * (shrapnel_hit_p)
        miss_p = (1 - shot_hit_p)
        
        """
        plt.plot(target_distance, win_p)
        plt.plot(target_distance, shrapnel_p)
        plt.plot(target_distance, miss_p)
        plt.plot(target_distance, win_p + shrapnel_p + miss_p)
        """

        #expected_value = 1*win_p + (0)*shrapnel_p + (-1)*miss_p
        expected_value = 1*shot_hit_p + (-1)*miss_p + (-1)*(shot_hit_p*shrapnel_hit_p)
        plt.figure("exp")
        plt.plot(target_distance, expected_value, color=f'C{i}', label=f"Shot std {np.degrees(shot_std):.1f}⁰")

        plt.figure("probs")
        plt.plot(target_distance, shot_hit_p, color=f'C{i}')
        plt.plot(target_distance, 1 - shrapnel_hit_p, '--', color=f'C{i}')
        #plt.plot(target_distance, shot_hit_p, color=f'C{i}', label=f"Shot std {np.degrees(shot_std):.1f}⁰")
        #plt.plot(target_distance, 1 - shrapnel_hit_p, '--', color=f'C{i}')
    plt.figure("exp")
    plt.legend()
    plt.show()

if __name__ == '__main__':
    #study_hit_probability()
    #plot_shot_hit_probability()
    #plot_shrapnel_hit_probability()
    plot_outcome_probability()
