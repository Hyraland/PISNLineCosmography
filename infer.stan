functions {
  real approx_dVddl(real dl) {
    return dl*dl/(0.07705049 + dl*(0.0742648 + dl*(0.00836159 + dl*0.00033334)));
  }

  int bisect_index(real x, real[] xs) {
    int n = size(xs);
    int i = 1;
    int j = n;
    real xi = xs[i];
    real xj = xs[j];

    if (x < xs[1] || x > xs[n]) reject("cannot interpolate out of bounds");

    while (j - i > 1) {
      int k = i + (j-i)/2;
      real xk = xs[k];

      if (x <= xk) {
        j = k;
        xj = xk;
      } else {
        i = k;
        xi = xk;
      }
    }

    return j;
  }

  real interp1d(real x, real[] xs, real[] ys) {
    int i = bisect_index(x, xs);

    real x0 = xs[i-1];
    real x1 = xs[i];
    real y0 = ys[i-1];
    real y1 = ys[i];

    real r = (x-x0)/(x1-x0);

    return r*y1 + (1.0-r)*y0;
  }

  real interp2d(real x, real y, real[] xs, real[] ys, real[,] zs) {
    int i = bisect_index(x, xs);
    int j = bisect_index(y, ys);

    real xl = xs[i-1];
    real xh = xs[i];
    real yl = ys[j-1];
    real yh = ys[j];

    real r = (x-xl)/(xh-xl);
    real s = (y-yl)/(yh-yl);

    return (1.0-r)*(1.0-s)*zs[i-1,j-1] + (1.0-r)*s*zs[i-1,j] + r*(1.0-s)*zs[i,j-1] + r*s*zs[i,j];
  }
}

data {
  real mc_obs;
  real eta_obs;
  real rho_obs;
  real theta_obs;

  real sigma_mc;
  real sigma_eta;
  real sigma_theta;

  int nm;
  real ms[nm];
  real opt_snrs[nm,nm];

  real dL_max;

  real mu_theta;
  real sig_theta;
}

transformed data {
  real minterp_min = min(ms);
  real minterp_max = max(ms);
}

parameters {
  real<lower=minterp_min, upper=minterp_max> m1;
  real<lower=minterp_min, upper=m1> m2;
  real<lower=0, upper=dL_max> dL;
  real<lower=0, upper=1> theta;
}

transformed parameters {
  real mc;
  real eta;
  real opt_snr;

  {
    real mt = m1+m2;

    eta = m1*m2/(mt*mt);
    mc = mt*eta^(3.0/5.0);
  }

  opt_snr = interp2d(m1, m2, ms, ms, opt_snrs)/dL;
}

model {
  /* flat-in-log prior on m1 */
  target += -log(m1);

  /* Flat prior on m2 */

  /* Mocked-up dVdz prior on */
  target += log(approx_dVddl(dL));

  theta ~ normal(mu_theta, sig_theta);

  // Observations; for some reason the ``T[a,b]`` truncation statements cause trouble.
  mc_obs ~ lognormal(log(mc), sigma_mc);
  eta_obs ~ normal(eta, sigma_eta);
  target += -log(normal_cdf(0.25, eta, sigma_eta) - normal_cdf(0, eta, sigma_eta)); // Truncated between 0 and 1/4
  rho_obs ~ normal(theta .* opt_snr, 1.0);
  theta_obs ~ normal(theta, sigma_theta);
  target += -log(normal_cdf(1, theta, sigma_theta) - normal_cdf(0, theta, sigma_theta)); // Truncated 0, 1
}

generated quantities {
  real log_m1m2dl_prior;

  log_m1m2dl_prior = -log(m1) + log(approx_dVddl(dL));
}