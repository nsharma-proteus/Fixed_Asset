def run(args) -> dict:
    """
    Action: Generate Asset Register Tag
    Builds a unique QR/barcode payload for the current asset and saves it
    into QR_CODE_BARCODE_TAG so it can be printed/scanned.
    """
    asset_code = args.get('asset_code')

    if is_empty(asset_code):
        return {'error': 'Asset Code is required before a tag can be generated.'}

    # Prefix the asset code so scanners can identify the payload as a
    # Fixed Asset Management (FAM) tag rather than a bare code value.
    tag = 'FAM-' + str(asset_code).strip()

    return {'updates': {'qr_barcode_tag': tag}}
