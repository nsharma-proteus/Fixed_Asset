def run(args):
    status = args.get('status')

    # Only assets awaiting approval can be capitalized
    if status != 'PENDING_APPROVAL':
        return {
            'errors': [{
                'code': 'ASSET_NOT_PENDING_APPROVAL',
                'field': 'status',
                'type': 'E',
                'message': 'Asset can only be approved when its status is Pending Approval.'
            }],
            'error': 'Asset can only be approved when its status is Pending Approval.'
        }

    updates = {'status': 'CAPITALIZED'}

    # Default capitalization date to today if not already set
    if is_empty(args.get('capitalization_date')):
        updates['capitalization_date'] = today()

    return {'updates': updates}
