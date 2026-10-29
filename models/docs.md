{% docs hcp_id %}
The HCP's 10-digit National Provider Identifier (NPI). In this project it is fake,
but it follows the real format and is validated by the `valid_npi` test.
{% enddocs %}

{% docs decile %}
Prescriber value ranking from 1 (lowest volume) to 10 (highest), based on the HCP's
market prescribing in the therapeutic area. Drives targeting and call planning.
{% enddocs %}

{% docs trx %}
**Total prescriptions** — new prescriptions plus refills dispensed in the week.
The standard volume measure for quota and IC crediting.
{% enddocs %}

{% docs nrx %}
**New prescriptions** — first fills only. A leading indicator of brand adoption.
NRx can never exceed TRx (enforced by a singular test).
{% enddocs %}

{% docs attainment_pct %}
Credited actual TRx ÷ quota TRx for the territory, brand and quarter. 1.00 = 100% of plan.
{% enddocs %}

{% docs weighted_attainment %}
Sum over the rep's brands of (brand attainment × brand IC weight from the `ic_product_weights` seed).
This single number is looked up on the payout curve.
{% enddocs %}

{% docs alignment %}
Point-in-time HCP → territory alignment derived from the `hcps_snapshot` SCD2 table.
Rx is credited to the territory the HCP belonged to in the week the Rx was written,
so realignments never rewrite past payouts.
{% enddocs %}
