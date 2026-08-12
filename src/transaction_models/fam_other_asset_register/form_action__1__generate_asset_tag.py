# project: Fixed_Asset
# object_type: T
# object_name: fam_other_asset_register
# event_type: form_action
# function_name: generate_asset_tag
# form_no: 1
# action_name: Generate QR/Barcode Tag
# language: python
# description: Generate a QR code / barcode tag for the item
# functional_specification: Generate a scannable QR/barcode payload (e.g. a short encoded string or URL embedding ASSET_CODE) that uniquely identifies this item, and return {"updates": {"qr_barcode_tag": {"value": <generated tag>, "protect": "1"}}} so the generated tag becomes read-only on the form. This function is shared by both the fam_asset_register and fam_other_asset_register transaction screens.
# business_logic: Generate a QR code / barcode tag for the item

def run(args):
    asset_code = args.get('ASSET_CODE', '')
    category_code = coalesce(args.get('CATEGORY_CODE'), '')
    branch_code = coalesce(args.get('BRANCH_CODE'), '')

    # Pipe-delimited payload: type | asset | category | branch | timestamp
    # Compact enough for a barcode; rich enough for a QR scan to identify the item fully.
    ts = datetime.datetime.now().strftime('%Y%m%d%H%M%S')
    tag = 'FAM|' + asset_code + '|' + category_code + '|' + branch_code + '|' + ts

    return {
        'updates': {
            'QR_BARCODE_TAG': {'value': tag, 'protect': '1'},
        }
    }
