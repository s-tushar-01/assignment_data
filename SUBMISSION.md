# Submission Notes

| Step | Description | Result | Reason |
|---|---|---:|---|
| 1 | Start with all communication log rows, treating every row as one send event | **30** | This is the naive starting point: no filters and no deduplication are applied, so every communication-log row is counted. |
| 2 | Exclude ineligible campaign 9004 | **26** | Campaign 9004 is `approval_awaiting`; its approval never cleared, so its 4 communication rows do not contribute. |
| 3 | Build the campaign hierarchy and apply the required scope filters | **26** | The recursive tree only establishes family structure; it removes no rows. Merchant 501, communication type 2, and October 2026 are also required scope filters and cause no change on this extract. |
| 4 | Collapse retry family 9001 → 9002 → 9003 | **23** | The three campaigns contain repeated attempts for the same customers. Counting distinct customers across the family reduces the total by 3. |
| 5 | Collapse retry family 9201 → 9202 | **22** | D1 appears in both campaigns as a retry, so the family is counted by distinct customers rather than communication rows, reducing the total by 1. |
| 6 | Do not deduplicate standalone campaign 9101 | **22** | 9101 has no retry relationship. C20 was intentionally sent twice, ten days apart, and both sends were delivered, so both are genuine communication events and must remain counted. |
| 7 | Test successful-delivery filtering | **22** | Adding `delivery_status = 900` produces no change on this extract. Failed attempts are removed, but the affected customers survive through successful retries. The filter is therefore not a neutral rule; it simply happens to produce the same result here. |
| 8 | Final per-family `target_base` total | **22** | The three family totals are 10 for 9001, 7 for standalone 9101, and 5 for 9201, giving a final total of **22**. |

## Surprise Paragraph

The most important surprise is that filtering to successful deliveries is not a neutral step; it simply happens to leave the final result unchanged in this dataset. In the 9001 retry family, failed attempts for C2 and C3 are removed by the filter, but those customers survive through successful retries. If C3 had also failed on its final attempt, the filter would remove C3 completely and the result would fall to 21. This shows why delivery status should not be used as the definition of `target_base`.

Another interesting finding is that the same repeated customer can mean two different things depending on campaign structure: a repeated customer is collapsed when it represents a retry in a campaign chain, but counted twice when it represents genuine re-targeting in a standalone campaign such as 9101.

Finally, campaign 9004 had four successfully delivered sends even though its approval never cleared. Those messages were actually sent to customers, but they are excluded from Finance's `target_base`, highlighting a genuine operational and financial gap rather than simply a data-filtering issue.

## Additional Note

The shared folder also contained `generate_dataset.py`. The analysis and final result were based on the database and assignment requirements, without relying on the dataset-generation script.