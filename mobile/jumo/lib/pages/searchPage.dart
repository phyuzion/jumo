import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../graphql/queries.dart';
import '../util/constants.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({Key? key}) : super(key: key);

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final box = GetStorage();
  final List<dynamic> _results = [];
  bool _isLoading = false;
  String? _errorMessage;

  late GraphQLClient _client;
  String _userId = "";
  String _userPhone = "";

  @override
  void initState() {
    super.initState();
    _loadUserCredentials();
  }

  void _loadUserCredentials() {
    _userId = box.read(USER_ID_KEY) ?? "";
    _userPhone = box.read(USER_PHONE_KEY) ?? "";
  }

  Future<void> _search() async {
    final searchText = _searchController.text.trim();
    if (searchText.isEmpty) {
      setState(() {
        _errorMessage = "검색어를 입력하세요.";
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _results.clear();
    });
    _client = GraphQLProvider.of(context).value;
    final QueryOptions options = QueryOptions(
      document: gql(GET_CUSTOMER_BY_PHONE),
      variables: {
        // 어드민이면 userId, phone 없이 호출할 수 있고, 유저면 해당 값을 전달
        'userId': _userId.isNotEmpty ? _userId : null,
        'phone': _userPhone.isNotEmpty ? _userPhone : null,
        'searchPhone': searchText,
      },
      fetchPolicy: FetchPolicy.networkOnly,
    );
    final result = await _client.query(options);
    if (result.hasException) {
      setState(() {
        _errorMessage = result.exception.toString();
      });
    } else {
      final data = result.data?['getCustomerByPhone'] as List<dynamic>?;
      if (data != null && data.isNotEmpty) {
        setState(() {
          _results.addAll(data);
        });
      } else {
        setState(() {
          _errorMessage = "검색 결과가 없습니다.";
        });
      }
    }
    setState(() {
      _isLoading = false;
    });
  }

  Widget _buildResultItem(dynamic item) {
    // item: { customer: {...}, callLogs: [...] }
    final customer = item['customer'];
    return ListTile(
      title: Text(customer['phone'] ?? 'Unknown'),
      subtitle: Text(
        '총 통화: ${customer['totalCalls']} / 평균점수: ${customer['averageScore']}',
      ),
      // 필요 시 추가로 callLogs 목록을 보여주거나, 상세 페이지로 이동할 수 있습니다.
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("검색 페이지"),
        actions: [
          Container(
            width: 200,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: '전화번호 검색',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
              ),
              keyboardType: TextInputType.phone,
            ),
          ),
          IconButton(onPressed: _search, icon: const Icon(Icons.search)),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : _results.isEmpty
              ? const Center(child: Text("검색 결과가 없습니다."))
              : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _results.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  return _buildResultItem(_results[index]);
                },
              ),
    );
  }
}
