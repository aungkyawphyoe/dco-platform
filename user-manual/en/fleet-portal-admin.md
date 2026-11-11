# AutoX Fleet Portal · Administrator guide

**Showroom handover status — 10 November 2026:** The staff handover flow is planned, not yet available in the Fleet Portal. The existing Transferred page is a read-only audit view. See the [approved implementation plan](../../product/frd/showroom-handover-plan.md) for future recipient verification, maintenance review, permissions, and correction rules; these are not current user instructions.

Use this guide to get a driver ready for their first shift, follow up on repairs, and review fleet records.

## Contents

1. [Sign in to your fleet](#sign-in-to-your-fleet)
2. [Add a vehicle](#add-a-vehicle)
3. [Give a driver access](#give-a-driver-access)
4. [Assign the vehicle](#assign-the-vehicle)
5. [Prepare an inspection checklist](#prepare-an-inspection-checklist)
6. [Take a repair from report to completion](#take-a-repair-from-report-to-completion)
7. [Decide whether to accept a submitted change](#decide-whether-to-accept-a-submitted-change)
8. [Download a fleet report](#download-a-fleet-report)
9. [Build a maintenance plan for a vehicle](#build-a-maintenance-plan-for-a-vehicle)
10. [Investigate high operating costs](#investigate-high-operating-costs)
11. [Set up warranty coverage and check transferred vehicles](#set-up-warranty-coverage-and-check-transferred-vehicles)
12. [Troubleshooting](#troubleshooting)

**Guide symbols** · ⚠️ Warning marks an action that affects access or records. ℹ️ Note explains a system behavior.

## Sign in to your fleet

Your administrator account opens the organization’s fleet workspace. The dashboard brings together today’s priorities, fleet status, and operating costs for the month. Start here at the beginning of a shift, then open the relevant record to act on it.

1. Open the Fleet Portal address supplied by your organization in a browser with an internet connection.
2. Enter your fleet administrator email and password and sign in.
3. If prompted, enter your temporary password under **Current password**. Enter and confirm your new password, then submit the form.
4. Open **Vehicles** and check the inventory before adding your first vehicle.

## Add a vehicle

The vehicle record connects its drivers, inspections, service history, and costs. Its class, fuel, and lifecycle also determine which maintenance items apply. Use the plate to distinguish vehicles with similar names.

1. In **Vehicles**, search for the license plate to check whether the vehicle already exists.
2. Click **Add vehicle**. Enter a recognizable name, make, model, year, and license plate. Use the vehicle’s own records to fill in its details. VIN means the 17-character vehicle identification number.
3. Select the fuel, vehicle class, and lifecycle that match the vehicle. Enter its current odometer reading in kilometers.
4. Click **Add vehicle**. Find the vehicle in the inventory and check the plate and distance.

## Change a vehicle’s status

Implemented locally on 11 November 2026; availability depends on deployment.

1. Open **Vehicles**, find the vehicle, and click **View**. The inventory displays statuses and filters but no longer changes statuses directly or in bulk.
2. In **Vehicle status**, read the current status description. Expand **What each status means** for the lifecycle guide.
3. As an organization admin or manager, select a valid next status. Read its explanation, then click **Save status**. Selection alone does not save.
4. Check **Status saved** and the updated status. If the vehicle changed while you were reviewing it, choose again from the refreshed state.

**Sold** cannot be selected manually. It requires completed handover; the new handover preparation flow is still pending.

## Give a driver access

A member account identifies the person signing in. Its role controls what that person can do. Choose the driver role for someone who needs the mobile workflows. Vehicle access comes from a separate assignment.

1. Open **Members** and click **Add member**.
2. Enter a new email address for the driver’s dedicated organization account. Select the driver role.
3. Enter a temporary password or leave the field blank to generate one. Click **Add member**.
4. Copy the password from **Member added** before clicking **Done**. Give the driver their sign-in email and temporary password through your organization’s private channel.
5. Ask the driver to sign in to the mobile app and change the temporary password.

> ⚠️ **Warning** · The portal shows the temporary password once. It does not send a welcome email.

## Assign the vehicle

An assignment links one driver to one vehicle. A driver can have several assignments, and several drivers can share a vehicle. Ending one pair lets you change the shift roster while keeping its assignment history.

1. Open **Driver Assignments** and click **Assign driver**.
2. Select the vehicle by name and plate. Select the driver, then click **Assign**.
3. Check that the pair appears under **Active assignments**. Ask the driver to select the vehicle in their mobile garage and confirm the plate.
4. When the assignment ends, locate that exact vehicle and driver pair and click **Unassign**. Check **History** for the ended assignment.

> 📷 **Screenshot placeholder A1 — Driver assignment.** Point to the two selectors and **Assign**. Show a matching sample plate and driver in **Active assignments**.

## Prepare an inspection checklist

A checklist template is a reusable set of questions. Each driver inspection creates a separate result from that checklist, so you can review checks across shifts without creating a new template each time.

1. Open **Inspections** and click **New template**.
2. Enter a **Template name** the driver will recognize, such as “Van pre-trip check.”
3. Enter one check per line under **Checklist items**. For example, put “Headlights work” and “Brake lights work” on separate lines.
4. Click **Create** and find the checklist under **Checklist templates**. Give its name to the driver so they can select it when they start an inspection.
5. After the driver submits the checklist, open **Inspection history** to check the result. For a failed inspection, open **Work Orders** to follow up.

## Take a repair from report to completion

A work order tracks one repair from the initial report to the recorded cost. Drivers can report issues directly, and a failed inspection can also create an order. Read the existing order before arranging the work.

1. Open **Work Orders**. Under **Reported**, find the correct vehicle and read the driver’s description.
2. Click **Start work**, select the person taking the job under **Assign to**, and click **Start**. Check that the order moves to **In progress**.
3. After the repair, click **Mark completed**. Enter the completion cost in the currency shown and add resolution notes, such as the part replaced.
4. Click **Complete**. Check the order under **Completed**.

> ℹ️ **Note** · The portal does not convert repair costs. If the invoice uses another currency, enter the equivalent in the displayed currency. You can record the original amount in the notes.

## Decide whether to accept a submitted change

Submission Review is where you resolve offline entries or corrections that need a decision. Comparing the proposed and current values helps you catch cases such as a mileage correction that would replace a newer reading.

1. Open **Submission Review**. Find the pending entry and check the vehicle and submitter.
2. Click **Compare with current record**. Read the proposed change alongside the saved values. For a new entry, the portal explains that there is no current record.
3. Click **Accept submission** to apply a correct change. If the proposal is a deletion, check the record carefully before clicking **Accept deletion**. Click **Reject** to decline the proposal instead.
4. Check the entry’s updated status.

> 📷 **Screenshot placeholder A2 — Review a correction.** Highlight the differing values in **Proposed change** and **Current record**. Point to the decision buttons. Use a sample correction.

## Download a fleet report

Download a report when you need a snapshot to share or analyze outside the portal. Choose the inventory for vehicle details, the cost report for spending, or the flagged list to investigate high running costs.

1. Open **Reports** and choose the report that answers your question.

   | To find | Choose |
   | --- | --- |
   | Vehicles in your fleet | **Vehicle inventory** |
   | Fleet costs | **Fleet cost report** |
   | Vehicles flagged for high costs | **Lemon flags** |

2. Click **Download** beside that report.
3. Open the downloaded CSV file (a table of values) in your spreadsheet application.

## Build a maintenance plan for a vehicle

The **Maintenance Catalog** holds reusable service intervals. A vehicle’s **Maintenance plan** holds the actual items you want its driver to follow. This lets you use the same oil-change interval across similar vehicles and still leave out work that does not apply to a particular one.

1. Open **Maintenance Catalog**. Filter by vehicle class and fuel type. Find the service and check its time and distance intervals.
2. If your fleet uses a different interval, click **Copy to org** on the global item. Set the interval and create the organization copy. Use **Edit** for an existing organization copy.
3. Open **Vehicles**, find the vehicle by plate, and click **View**. Under **Maintenance template set**, select the set for its class and click **Assign**.
4. Review **Items in this set**. Clear the checkbox for any service you want to skip. **Already in plan** identifies existing items.
5. Click **Generate plan** and confirm. Check the number added, then review the vehicle’s **Maintenance plan**. Use **Service history** to see completed work.

> 📷 **Screenshot placeholder A3 — Generate a plan.** Highlight the template set, one selected item, an **Already in plan** badge, and **Generate plan**.

## Investigate high operating costs

1. Start on **Dashboard** to see this month’s operating costs. Open **Analytics** when you need to understand a change or compare vehicles.
2. Choose **Cost overview** to see spending by category and over time. Open the underlying expense records where available to find what contributed to a total.
3. Choose **Efficiency** to examine fuel and charging use. A gap in a monthly chart means the month lacks data. Choose **Vehicle comparison** to compare vehicles side by side.
4. To change which vehicles count as unusually costly, open **Org Settings → Lemon threshold**. Choose **Multiplier of fleet average** for a limit relative to your fleet, or enter a fixed cost per kilometer in Myanmar kyat (MMK).
5. Click **Save threshold** and check the current threshold. Open **Reports → Lemon flags** to download the list for investigation.

> ℹ️ **Note** · A “lemon flag” identifies a vehicle that crosses the cost threshold. Check its expense and service records to understand the cause.

## Set up warranty coverage and check transferred vehicles

A warranty template records the terms your organization uses when transferring a vehicle to a buyer. Approved workshops identify service partners covered by those terms.

1. Open **Workshops** and click **Approve workshop**. Enter the verified partner’s workshop ID, the unique identifier supplied for that partner, then click **Approve**. Check the approved list.
2. Open **Warranty Templates** and click **New template**. Give the terms a recognizable name. Enter the duration in years and the mileage limit in kilometers.
3. Enter the covered categories, exclusions, and applicable workshop IDs. Separate multiple categories or IDs with commas. Click **Create** and check the limits on the saved template.
4. After a showroom vehicle transfers to a buyer, open **Transferred**. Use this read-only log to check the transfer and its linked warranty.

## Troubleshooting

| What you see | What to do |
| --- | --- |
| A driver expects an invitation email | Give them the account email and temporary password you copied when adding the member. |
| A driver cannot see the vehicle | Match their sign-in email to **Members**, then check the plate and driver together under **Active assignments**. |
| A driver sees no inspection checklist | Open **Inspections**, create a checklist with at least one item, and ask the driver to reopen the inspection. |
| A repair cost will not save | Check the displayed currency. Enter a nonnegative whole amount for Myanmar kyat (MMK), or up to two decimal places for other currencies. If the currency changed, select the current currency and re-enter the cost. |
| You see **Fleet Admin access required** | Check that you signed in with your fleet administrator account before opening **Submission Review**. |
