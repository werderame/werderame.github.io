import pandas as pd
import time

# with forecast_df and stock_df as the demand and inventory DataFrames respectively
def calculate_fefo(forecast_df, stock_df):
    # Organize inventory data by product and DC, and sort by discardment date and palletId
    product_batches = {}
    for index, row in stock_df.iterrows():
        product_id = row['sku_code']
        dc = row['dc_code']
        key = f"{product_id}_{dc}"

        if key not in product_batches:
            product_batches[key] = []

        product_batches[key].append({
            'product_id': product_id,
            'dc': dc,
            'pallet_id': row['tm_id__po_id'],
            'batch_id': row['lot_code'],
            'location': row['location_id'],
            'expiration_date': pd.to_datetime(row['expiration_date']) if row['expiration_date'] else '',
            'initial_stock': row['quantity'],
            'stock': row['quantity'],
            'category': row['category'],
            'cost': row['unit_cost'],
            'product_type': row['product_types'],
            'hellofresh_week': row['hellofresh_week'],
            'hf_week_out': row['hf_week_out'],
            'temperature_class': row['temperature_class'],
            'data_source': row['data_source'],
            'discardment_date': pd.to_datetime(row['discardment_date']) if row['discardment_date'] else '',
            'logical_mlor': row['logical_mlor'] if row['logical_mlor'] else '',
            'mlor_source': row['mlor_source'] if row['mlor_source'] else '',
            'snapshot_time': pd.to_datetime(row['snapshot_time']) if row['snapshot_time'] else '',
            'supplier_code': row['supplier_code'] if row['supplier_code'] else ''
        })

    # Sort batches by discardment date and then by palletId for each product and DC
    for key in product_batches:
        product_batches[key].sort(key=lambda x: (x['discardment_date'], x['pallet_id']))

    # Process demand data and update stock
    for index, row in forecast_df.iterrows():
        product_id = row['code']
        dc = row['distribution_center']
        quantity_sold = row['forecasted_demanded_qty']
        key = f"{product_id}_{dc}"

        if key in product_batches:
            for batch in product_batches[key]:
                if quantity_sold > 0 and (not batch['discardment_date'] or batch['discardment_date'] >= pd.to_datetime(row['production_date'])):
                    if batch['stock'] > 0:
                        qty_to_deduct = min(batch['stock'], quantity_sold)
                        batch['stock'] -= qty_to_deduct
                        quantity_sold -= qty_to_deduct

    # Include remaining stock and consumed stock after processing demand in the calculation data
    calc_data = []
    for key in product_batches:
        for batch in product_batches[key]:
            if batch['stock'] > 0 or batch['initial_stock'] > batch['stock']:
                calc_data.append([
                    batch['product_id'],
                    batch['batch_id'],
                    batch['pallet_id'],
                    batch['expiration_date'] if batch['expiration_date'] else '',
                    batch['discardment_date'] if batch['discardment_date'] else '',
                    batch['stock'],
                    batch['initial_stock'] - batch['stock'],
                    batch['dc'],
                    batch['location'],
                    batch['category'],
                    batch['cost'],
                    batch['cost'] * batch['stock'],
                    batch['product_type'],
                    batch['hellofresh_week'],
                    batch['hf_week_out'],
                    batch['temperature_class'],
                    batch['data_source'],
                    batch['logical_mlor'],
                    batch['mlor_source'],
                    batch['snapshot_time'],
                    batch['supplier_code']
                ])

    # Create a DataFrame from the calculation data
    calc_df = pd.DataFrame(calc_data, columns=[
        'sku_id', 'batch_id', 'pallet_id', 'expiration_date', 'discardment_date', 'remaining_qty', 'consumed_qty',
        'dc', 'location', 'category', 'unit_cost', 'line_cost', 'type', 'hf_week',
        'hf_week_out', 'temp_class', 'data_source', 'logical_mlor', 'mlor_source', 'snapshot_time', 'supplier_code'
    ])

    return calc_df