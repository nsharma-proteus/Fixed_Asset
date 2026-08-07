def run(args):
    status = args.get('status')

    # Only assets awaiting approval can be rejected back to Draft
    if status != 'PENDING_APPROVAL':
        return {
            'errors': [{
                'code': 'ASSET_NOT_PENDING_APPROVAL',
                'field': 'status',
                'type': 'E',
                'message': 'Asset can only be rejected when its status is Pending Approval.'
            }],
            'error': 'Asset can only be rejected when its status is Pending Approval.'
        }

    return {'updates': {'status': 'DRAFT'}}
